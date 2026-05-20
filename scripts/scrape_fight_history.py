import os
import re
import time
import random
import requests
import pandas as pd
from bs4 import BeautifulSoup
from urllib.parse import urljoin

# Optional: only needed for .RData export
try:
    import pyreadr
    HAS_PYREADR = True
except ImportError:
    HAS_PYREADR = False

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

# Base URLs
EVENTS_URL = "http://ufcstats.com/statistics/events/completed?page=all"
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
}

def clean_text(text):
    """Removes extra whitespace and newlines from scraped text."""
    if not text:
        return ""
    return re.sub(r'\s+', ' ', text.strip())

def get_event_links():
    """Scrapes the main page to get all completed event URLs."""
    logging.info("Fetching event list...")
    response = requests.get(EVENTS_URL, headers=HEADERS)
    soup = BeautifulSoup(response.content, 'html.parser')
    
    event_links = []
    # Skip the first row as it's the header
    rows = soup.select('.b-statistics__table-events tbody tr')[1:] 
    for row in rows:
        link_tag = row.select_first('a')
        if link_tag and 'href' in link_tag.attrs:
            event_links.append(link_tag['href'])
            
    logging.info(f"Found {len(event_links)} events.")
    return event_links

def get_fight_links(event_url):
    """Scrapes an event page to get URLs for all fights on the card."""
    response = requests.get(event_url, headers=HEADERS)
    soup = BeautifulSoup(response.content, 'html.parser')
    
    fight_links = []
    rows = soup.select('.b-fight-details__table-row')
    for row in rows:
        if 'data-link' in row.attrs:
            fight_links.append(row['data-link'])
            
    # Extract event info
    event_name = clean_text(soup.select_first('.b-content__title span').text)
    date_location_tags = soup.select('.b-list__box-list-item')
    date = clean_text(date_location_tags[0].text.replace('Date:', '')) if len(date_location_tags) > 0 else ""
    location = clean_text(date_location_tags[1].text.replace('Location:', '')) if len(date_location_tags) > 1 else ""
    
    return fight_links, event_name, date, location

def parse_fight_details(fight_url, event_name, date, location):
    """Extracts and flattens all details from a single fight page."""
    response = requests.get(fight_url, headers=HEADERS)
    soup = BeautifulSoup(response.content, 'html.parser')
    
    fight_data = {
        'fight_url': fight_url,
        'event_name': event_name,
        'date': date,
        'location': location
    }
    
    # 1. Fighter Names & Outcomes
    persons = soup.select('.b-fight-details__person')
    if len(persons) != 2:
        return None # Incomplete data structure
        
    for i, person in enumerate(persons):
        prefix = f'f{i+1}_'
        status = person.select_first('.b-fight-details__person-status').text.strip()
        name = clean_text(person.select_first('.b-fight-details__person-name a').text)
        fight_data[f'{prefix}name'] = name
        fight_data[f'{prefix}result'] = status

    # 2. General Fight Details (Weight class, Method, Round, Time, Judging Details)
    weight_class = clean_text(soup.select_first('.b-fight-details__fight-title').text)
    fight_data['weight_class'] = weight_class
    
    method_tag = soup.select_first('i.b-fight-details__text-item_first')
    fight_data['method'] = clean_text(method_tag.text.replace('Method:', '')) if method_tag else ""
    
    details_items = soup.select('.b-fight-details__text-item')
    for item in details_items:
        text = clean_text(item.text)
        if 'Round:' in text:
            fight_data['round'] = text.replace('Round:', '').strip()
        elif 'Time:' in text:
            fight_data['time'] = text.replace('Time:', '').strip()
        elif 'Time format:' in text:
            fight_data['time_format'] = text.replace('Time format:', '').strip()
        elif 'Referee:' in text:
            fight_data['referee'] = text.replace('Referee:', '').strip()

    # Judging details (often contains the exact judge scores)
    judging_section = soup.select('.b-fight-details__text')
    for section in judging_section:
        if 'Details:' in section.text:
            fight_data['judging_details'] = clean_text(section.text.replace('Details:', ''))

    # 3. Parse Statistical Tables (Totals & Significant Strikes)
    # The site duplicates tables for 'Overall' and 'Per Round'. We target the first two tables (Overall).
    tables = soup.select('.b-fight-details__table')
    if len(tables) >= 2:
        totals_table = tables[0]
        sig_str_table = tables[1]
        
        # Helper to flatten table rows
        def extract_table_stats(table, suffix_tag=""):
            headers = [clean_text(th.text) for th in table.select('thead th')]
            # The first row in tbody contains the overall fight totals
            first_row_tds = table.select('tbody tr')[0].select('td')
            
            for idx, td in enumerate(first_row_tds):
                if idx >= len(headers):
                    break
                header_name = headers[idx].lower().replace('.', '').replace(' ', '_').replace('%', 'pct')
                
                # Each td contains two <p> tags, one for Fighter 1, one for Fighter 2
                p_tags = td.select('p')
                if len(p_tags) == 2:
                    fight_data[f'f1_{header_name}{suffix_tag}'] = clean_text(p_tags[0].text)
                    fight_data[f'f2_{header_name}{suffix_tag}'] = clean_text(p_tags[1].text)

        extract_table_stats(totals_table, suffix_tag="_total")
        # For the significant strike table, skip the first 3 columns (Fighter, Sig Str, Sig Str %) to avoid duplicates
        # as they are already extracted in the totals table.
        headers = [clean_text(th.text) for th in sig_str_table.select('thead th')]
        first_row_tds = sig_str_table.select('tbody tr')[0].select('td')
        for idx, td in enumerate(first_row_tds):
            if idx < 3: # Skip duplicate total columns
                continue
            header_name = headers[idx].lower().replace('.', '').replace(' ', '_')
            p_tags = td.select('p')
            if len(p_tags) == 2:
                fight_data[f'f1_{header_name}_sig'] = clean_text(p_tags[0].text)
                fight_data[f'f2_{header_name}_sig'] = clean_text(p_tags[1].text)

    return fight_data

def main():
    event_links = get_event_links()
    
    # For a full data pull, leave this as is. 
    # For testing, you might want to slice the list: event_links = event_links[:2]
    
    all_fights_data = []
    
    # Loop through events
    for event_idx, event_url in enumerate(event_links):
        logging.info(f"Processing Event {event_idx + 1}/{len(event_links)}: {event_url}")
        fight_links, event_name, date, location = get_fight_links(event_url)
        
        # Loop through fights in the event
        for fight_url in fight_links:
            try:
                fight_data = parse_fight_details(fight_url, event_name, date, location)
                if fight_data:
                    all_fights_data.append(fight_data)
            except Exception as e:
                logging.error(f"Error parsing {fight_url}: {e}")
            
            # Respectful scraping delay
            time.sleep(1) 
            
    # Export to flattened CSV
    if all_fights_data:
        df = pd.DataFrame(all_fights_data)
        output_filename = 'ufc_flattened_fight_data.csv'
        df.to_csv(output_filename, index=False)
        logging.info(f"Data successfully saved to {output_filename}")
        logging.info(f"Total fights extracted: {len(df)}")
    else:
        logging.warning("No data extracted.")

if __name__ == "__main__":
    main()

import os
import re
import time
import random
import logging
import pandas as pd
from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Base URLs
EVENTS_URL = "http://ufcstats.com/statistics/events/completed?page=all"

def clean_text(text):
    """Removes extra whitespace and newlines from scraped text."""
    if not text:
        return ""
    return re.sub(r'\s+', ' ', text.strip())

def get_soup(url, page, expected_selector, retries=3, timeout=15000):
    """
    Fetches a URL using Playwright, explicitly waits for the target element, 
    and returns BeautifulSoup. Retries on failures.
    """
    for attempt in range(1, retries + 1):
        try:
            # We still wait for the DOM to load natively
            page.goto(url, wait_until="domcontentloaded", timeout=timeout)
            
            # CRITICAL FIX: Force Playwright to wait until the specific table/data actually exists
            page.wait_for_selector(expected_selector, timeout=timeout)
            
            return BeautifulSoup(page.content(), 'html.parser')
            
        except PlaywrightTimeoutError:
            page_title = page.title()
            # Check if we are stuck on a Cloudflare anti-bot page
            if "Just a moment" in page_title or "Cloudflare" in page_title:
                logging.warning(f"Cloudflare block detected on attempt {attempt} for {url}. Try setting headless=False.")
            else:
                logging.warning(f"Timeout waiting for '{expected_selector}' on attempt {attempt} for {url}")
                
        except Exception as e:
            logging.error(f"Attempt {attempt} failed for {url}: {e}")
            
        # Jittered sleep before retrying
        time.sleep(attempt * 2 + random.uniform(0.5, 1.5))
        
    logging.error(f"Giving up on {url} after {retries} attempts.")
    return None

def get_event_links(page):
    """Scrapes the main page to get all completed event URLs."""
    logging.info("Fetching event list...")
    
    # Pass the specific table selector we need to wait for
    soup = get_soup(EVENTS_URL, page, expected_selector='.b-statistics__table-events tbody tr')
    if not soup:
        return []
    
    event_links = []
    # No longer skipping [1:] here, we will filter cleanly in the loop
    rows = soup.select('.b-statistics__table-events tbody tr') 
    for row in rows:
        link_tag = row.find('a') 
        if link_tag and 'href' in link_tag.attrs:
            event_links.append(link_tag['href'])
            
    logging.info(f"Found {len(event_links)} events.")
    return event_links

def get_fight_links(event_url, page):
    """Scrapes an event page to get URLs for all fights on the card."""
    soup = get_soup(event_url, page, expected_selector='.b-event-details__table-row')
    if not soup:
        return [], "", "", ""
    
    fight_links = []
    rows = soup.select('.b-event-details__table-row')
    for row in rows:
        if 'data-link' in row.attrs:
            fight_links.append(row['data-link'])
            
    title_elem = soup.find(class_='b-content__title-highlight')
    event_name = clean_text(title_elem.text) if title_elem else ""
    
    date_location_tags = soup.select('.b-list__box-list-item')
    date = clean_text(date_location_tags[0].text.replace('Date:', '')) if len(date_location_tags) > 0 else ""
    location = clean_text(date_location_tags[1].text.replace('Location:', '')) if len(date_location_tags) > 1 else ""
    
    return fight_links, event_name, date, location

def parse_fight_details(fight_url, event_name, date, location, page):
    """Extracts and flattens total fight details from a single fight page."""
    soup = get_soup(fight_url, page, expected_selector='.b-event-details__person')
    if not soup:
        return None
    
    fight_data = {
        'fight_url': fight_url,
        'event_name': event_name,
        'date': date,
        'location': location
    }
    
    # 1. Fighter Names & Outcomes
    persons = soup.select('.b-event-details__person')
    if len(persons) != 2:
        return None # Incomplete data structure
        
    for i, person in enumerate(persons):
        prefix = f'f{i+1}_'
        status_tag = person.find(class_='b-event-details__person-status')
        status = status_tag.text.strip() if status_tag else ""
        
        name_container = person.find(class_='b-event-details__person-name')
        name_tag = name_container.find('a') if name_container else None
        name = clean_text(name_tag.text) if name_tag else ""
        
        fight_data[f'{prefix}name'] = name
        fight_data[f'{prefix}result'] = status

    # 2. General Fight Details
    weight_class_tag = soup.find(class_='b-event-details__fight-title')
    fight_data['weight_class'] = clean_text(weight_class_tag.text) if weight_class_tag else ""
    
    method_tag = soup.find('i', class_='b-event-details__text-item_first')
    fight_data['method'] = clean_text(method_tag.text.replace('Method:', '')) if method_tag else ""
    
    details_items = soup.select('.b-event-details__text-item')
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

    # Judging details
    judging_section = soup.select('.b-event-details__text')
    for section in judging_section:
        if 'Details:' in section.text:
            fight_data['judging_details'] = clean_text(section.text.replace('Details:', ''))

    # 3. Parse Statistical Tables (Fight Totals Only)
    tables = soup.select('.b-event-details__table')
    if len(tables) >= 2:
        totals_table = tables[0]
        sig_str_table = tables[1]
        
        def extract_table_stats(table, suffix_tag=""):
            headers = [clean_text(th.text) for th in table.select('thead th')]
            tbody = table.find('tbody')
            if not tbody: return
            
            # Selecting [0] grabs ONLY the total fight stats, skipping round-by-round breakdown
            first_row_tds = tbody.select('tr')[0].select('td')
            
            for idx, td in enumerate(first_row_tds):
                if idx >= len(headers):
                    break
                header_name = headers[idx].lower().replace('.', '').replace(' ', '_').replace('%', 'pct')
                
                p_tags = td.select('p')
                if len(p_tags) == 2:
                    fight_data[f'f1_{header_name}{suffix_tag}'] = clean_text(p_tags[0].text)
                    fight_data[f'f2_{header_name}{suffix_tag}'] = clean_text(p_tags[1].text)

        extract_table_stats(totals_table, suffix_tag="_total")
        
        headers = [clean_text(th.text) for th in sig_str_table.select('thead th')]
        tbody = sig_str_table.find('tbody')
        if tbody:
            first_row_tds = tbody.select('tr')[0].select('td')
            for idx, td in enumerate(first_row_tds):
                if idx < 3: 
                    continue
                header_name = headers[idx].lower().replace('.', '').replace(' ', '_')
                p_tags = td.select('p')
                if len(p_tags) == 2:
                    fight_data[f'f1_{header_name}_sig'] = clean_text(p_tags[0].text)
                    fight_data[f'f2_{header_name}_sig'] = clean_text(p_tags[1].text)

    return fight_data

def main():
    all_fights_data = []
    
    with sync_playwright() as p:
        # If it still fails, change headless=True to headless=False so you can visually see the issue
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
            viewport={'width': 1920, 'height': 1080}
        )
        page = context.new_page()
        
        event_links = get_event_links(page)
        
        # NOTE: You can slice event_links[:2] here if you want to test a smaller batch first
        for event_idx, event_url in enumerate(event_links):
            logging.info(f"Processing Event {event_idx + 1}/{len(event_links)}: {event_url}")
            fight_links, event_name, date, location = get_fight_links(event_url, page)
            
            for fight_url in fight_links:
                try:
                    fight_data = parse_fight_details(fight_url, event_name, date, location, page)
                    if fight_data:
                        all_fights_data.append(fight_data)
                except Exception as e:
                    logging.error(f"Error parsing {fight_url}: {e}")
                
                time.sleep(1 + random.uniform(0.1, 0.5)) 
                
        browser.close()
            
    # Export data
    if all_fights_data:
        os.makedirs('./data', exist_ok=True)
        df = pd.DataFrame(all_fights_data)
        
        csv_filename = './data/ufc_fights.csv'
        df.to_csv(csv_filename, index=False)
        logging.info(f"Data successfully saved to {csv_filename}")
        logging.info(f"Total fights extracted: {len(df)}")
    else:
        logging.warning("No data extracted.")

if __name__ == "__main__":
    main()

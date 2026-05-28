from playwright.sync_api import sync_playwright
from bs4 import BeautifulSoup
import pandas as pd
import time
import re
import logging
import os

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

# 1. FIX SUBDOMAIN: Route to www. to avoid 301 parameter-stripping redirects
EVENTS_URL = "http://www.ufcstats.com/statistics/events/completed?page=all"

def clean_text(text):
    if not text:
        return ""
    return re.sub(r'\s+', ' ', text.strip())

def get_event_links(page):
    logging.info("Fetching event list...")
    page.goto(EVENTS_URL, wait_until="domcontentloaded")
    
    # Wait for event link selector to verify challenge has passed
    try:
        page.wait_for_selector('a[href*="/event-details/"]', timeout=20000)
    except Exception as e:
        logging.error(f"Timeout waiting for event links page to load: {e}")
        return []
        
    soup = BeautifulSoup(page.content(), 'html.parser')

    event_links = []
    for link_tag in soup.find_all('a', href=re.compile(r'/event-details/')):
        href = link_tag['href']
        full_url = href if href.startswith('http') else 'http://www.ufcstats.com' + href
        full_url = full_url.replace('http://ufcstats.com', 'http://www.ufcstats.com')
        if full_url not in event_links:
            event_links.append(full_url)

    logging.info(f"Found {len(event_links)} events.")
    return event_links

def get_fight_links(event_url, page):
    page.goto(event_url, wait_until="domcontentloaded")
    
    # Wait for the fight rows to generate safely
    try:
        page.wait_for_selector('.b-fight-details__table-row', timeout=15000)
    except Exception as e:
        logging.error(f"Timeout waiting for fight rows on event page: {event_url}. Error: {e}")
        return [], "", "", ""

    soup = BeautifulSoup(page.content(), 'html.parser')

    fight_links = []
    rows = soup.select('.b-fight-details__table-row')
    for row in rows:
        if 'data-link' in row.attrs:
            fight_links.append(row['data-link'])

    title_span = soup.find(class_='b-content__title')
    event_name = clean_text(title_span.find('span').text) if title_span and title_span.find('span') else ""

    date_location_tags = soup.select('.b-list__box-list-item')
    date = clean_text(date_location_tags[0].text.replace('Date:', '')) if len(date_location_tags) > 0 else ""
    location = clean_text(date_location_tags[1].text.replace('Location:', '')) if len(date_location_tags) > 1 else ""

    logging.info(f"  Found {len(fight_links)} fights — {event_name}")
    return fight_links, event_name, date, location

def parse_fight_details(fight_url, event_name, date, location, page):
    fight_url_fixed = fight_url.replace('http://ufcstats.com', 'http://www.ufcstats.com')
    page.goto(fight_url_fixed, wait_until="domcontentloaded")
    
    # Wait for fighter details container to load 
    try:
        page.wait_for_selector('.b-fight-details__person', timeout=15000)
    except Exception as e:
        logging.error(f"Timeout waiting for fight details to load: {fight_url_fixed}. Error: {e}")
        return None

    soup = BeautifulSoup(page.content(), 'html.parser')

    fight_data = {
        'fight_url': fight_url_fixed,
        'event_name': event_name,
        'date': date,
        'location': location
    }

    persons = soup.select('.b-fight-details__person')
    if len(persons) != 2:
        return None

    for i, person in enumerate(persons):
        prefix = f'f{i+1}_'
        status_tag = person.find(class_='b-fight-details__person-status')
        status = status_tag.text.strip() if status_tag else ""
        name_container = person.find(class_='b-fight-details__person-name')
        name_tag = name_container.find('a') if name_container else None
        name = clean_text(name_tag.text) if name_tag else ""
        fight_data[f'{prefix}name'] = name
        fight_data[f'{prefix}result'] = status

    weight_class_tag = soup.find(class_='b-fight-details__fight-title')
    fight_data['weight_class'] = clean_text(weight_class_tag.text) if weight_class_tag else ""

    method_tag = soup.find('i', class_='b-fight-details__text-item_first')
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

    judging_section = soup.select('.b-fight-details__text')
    for section in judging_section:
        if 'Details:' in section.text:
            fight_data['judging_details'] = clean_text(section.text.replace('Details:', ''))

    tables = soup.select('.b-fight-details__table')
    if len(tables) >= 2:
        totals_table = tables[0]
        sig_str_table = tables[1]

        def extract_table_stats(table, suffix_tag=""):
            headers = [clean_text(th.text) for th in table.select('thead th')]
            tbody = table.find('tbody')
            if not tbody:
                return
            tbody_rows = tbody.select('tr')
            if not tbody_rows:
                return
            first_row_tds = tbody_rows[0].select('td')
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
            tbody_rows = tbody.select('tr')
            if tbody_rows:
                first_row_tds = tbody_rows[0].select('td')
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

    # Initialize Playwright Engine Context
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        )
        page = context.new_page()

        try:
            event_links = get_event_links(page)
        except Exception as e:
            logging.error(f"Failed to fetch event links: {e}")
            event_links = []

        # Optimization Tip: To test first, slice this list: event_links[:3]
        for event_idx, event_url in enumerate(event_links):
            logging.info(f"Processing Event {event_idx + 1}/{len(event_links)}: {event_url}")
            try:
                fight_links, event_name, date, location = get_fight_links(event_url, page)
            except Exception as e:
                logging.error(f"Error gathering fight links for {event_url}: {e}")
                continue

            for fight_url in fight_links:
                try:
                    fight_data = parse_fight_details(fight_url, event_name, date, location, page)
                    if fight_data:
                        all_fights_data.append(fight_data)
                except Exception as e:
                    logging.error(f"Error parsing {fight_url}: {e}")
                
                time.sleep(1)

        browser.close()

    if all_fights_data:
        df = pd.DataFrame(all_fights_data)
        os.makedirs('./data', exist_ok=True)
        csv_filename = './data/ufc_fights.csv'
        df.to_csv(csv_filename, index=False)
        logging.info(f"Data successfully saved to {csv_filename}")
        logging.info(f"Total fights extracted: {len(df)}")
    else:
        logging.warning("No data extracted.")

if __name__ == "__main__":
    main()

import os
from pathlib import Path
import logging
import pandas as pd
import time
import re
import string
import random
from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def get_soup(url, page, retries=3, timeout=15000):
    """Fetches a URL using Playwright and returns BeautifulSoup. Retries on failures."""
    for attempt in range(1, retries + 1):
        try:
            page.goto(url, wait_until="domcontentloaded", timeout=timeout)
            return BeautifulSoup(page.content(), 'html.parser')
        except PlaywrightTimeoutError:
            logging.warning(f"Timeout on attempt {attempt} for {url}")
        except Exception as e:
            logging.error(f"Attempt {attempt} failed for {url}: {e}")
            
        time.sleep(attempt * 2 + random.uniform(0.5, 1.5))
        
    logging.error(f"Giving up on {url} after {retries} attempts.")
    return None

def get_fighter_links(letter, page):
    url = f"http://ufcstats.com/statistics/fighters?char={letter}&page=all"
    soup = get_soup(url, page)
    
    links = []
    if not soup:
        return links
        
    table = soup.find('table', class_='b-statistics__table')
    if not table:
        return links
        
    rows = table.find_all('tr', class_='b-statistics__table-row')[2:] 
    for row in rows:
        a_tag = row.find('a', class_='b-link')
        if a_tag and 'href' in a_tag.attrs:
            links.append(a_tag['href'])
            
    return links

def parse_fighter_details(url, page):
    soup = get_soup(url, page)
    
    fighter_data = {
        'Name': None, 'Wins': 0, 'Losses': 0, 'Draws': 0, 'NC': 0,
        'Height': None, 'Weight': None, 'Reach': None, 'STANCE': None, 'DOB': None,
        'SLpM': None, 'Str. Acc.': None, 'SApM': None, 'Str. Def.': None,
        'TD Avg.': None, 'TD Acc.': None, 'TD Def.': None, 'Sub. Avg.': None
    }
    
    if not soup:
        return fighter_data

    name_tag = soup.find('span', class_='b-content__title-highlight')
    if name_tag:
        fighter_data['Name'] = name_tag.text.strip()
        
    record_tag = soup.find('span', class_='b-content__title-record')
    if record_tag:
        record_str = record_tag.text.strip() 
        match = re.search(r'Record:\s*(\d+)-(\d+)-(\d+)(?:\s*\((?:(\d+)\s*NC)?\))?', record_str)
        if match:
            fighter_data['Wins'] = int(match.group(1))
            fighter_data['Losses'] = int(match.group(2))
            fighter_data['Draws'] = int(match.group(3))
            if match.group(4):
                fighter_data['NC'] = int(match.group(4))

    list_items = soup.find_all('li', class_='b-list__box-list-item')
    
    for item in list_items:
        title_tag = item.find('i', class_='b-list__box-item-title')
        if title_tag:
            title = title_tag.text.strip().replace(':', '')
            value = item.text.replace(title_tag.text, '').strip()
            
            stat_map = {
                'Height': 'Height', 'Weight': 'Weight', 'Reach': 'Reach',
                'STANCE': 'STANCE', 'DOB': 'DOB', 'SLpM': 'SLpM',
                'Str. Acc.': 'Str. Acc.', 'SApM': 'SApM', 'Str. Def': 'Str. Def.',
                'TD Avg.': 'TD Avg.', 'TD Acc.': 'TD Acc.', 'TD Def.': 'TD Def.',
                'Sub. Avg.': 'Sub. Avg.'
            }
            
            if title in stat_map:
                fighter_data[stat_map[title]] = None if value == '--' else value

    return fighter_data

def scrape_all_fighters(letters_to_scrape, page):
    all_fighters = []
    
    for letter in letters_to_scrape:
        logging.info(f"Fetching links for '{letter.upper()}'...")
        fighter_links = get_fighter_links(letter, page)
        
        for i, link in enumerate(fighter_links):
            logging.info(f"Scraping fighter {i+1}/{len(fighter_links)}: {link}")
            try:
                data = parse_fighter_details(link, page)
                all_fighters.append(data)
            except Exception as e:
                logging.error(f"Error scraping {link}: {e}")
                
            time.sleep(0.5 + random.uniform(0.1, 0.4)) 
            
    df = pd.DataFrame(all_fighters)
    return df

def main():
    test_letters = string.ascii_lowercase
    logging.info("Starting scraper...")

    Path("./data").mkdir(parents=True, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
        )
        page = context.new_page()

        df_fighters = scrape_all_fighters(letters_to_scrape=test_letters, page=page)
        
        browser.close()

    if not df_fighters.empty:
        csv_filename = './data/ufcstats_data.csv'
        df_fighters.to_csv(csv_filename, index=False)
        logging.info(f"Saved {len(df_fighters)} rows to {csv_filename}")
    else:
        logging.warning("No data was extracted.")

if __name__ == "__main__":
    main()

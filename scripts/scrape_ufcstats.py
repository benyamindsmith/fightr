import os
import re
import time
import random
import string
import logging
import pandas as pd
from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

# Configure Logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Base URL for formatting
FIGHTERS_BASE_URL = "http://ufcstats.com/statistics/fighters?char={}&page=all"

def clean_text(text):
    """Removes extra whitespace and newlines from scraped text."""
    if not text:
        return ""
    return re.sub(r'\s+', ' ', text.strip())

def get_soup(url, page, retries=3, timeout=15000):
    """Fetches a URL using Playwright and returns a BeautifulSoup object. Retries on failure."""
    for attempt in range(1, retries + 1):
        try:
            # Wait until the DOM is fully loaded to ensure the table is present
            page.goto(url, wait_until="domcontentloaded", timeout=timeout)
            return BeautifulSoup(page.content(), 'html.parser')
            
        except PlaywrightTimeoutError:
            logging.warning(f"Timeout on attempt {attempt} for {url}")
        except Exception as e:
            logging.error(f"Attempt {attempt} failed for {url}: {e}")
            
        # Jittered sleep to avoid rate-limiting
        time.sleep(attempt * 2 + random.uniform(0.5, 1.5))
        
    logging.error(f"Giving up on {url} after {retries} attempts.")
    return None

def parse_fighters_page(soup):
    """Extracts fighter data from the table on the current page."""
    fighters_data = []
    
    # Target the main statistics table
    table = soup.find('table', class_='b-statistics__table')
    if not table:
        return fighters_data
        
    # Skip the header row(s) and iterate through fighter rows
    rows = table.find_all('tr', class_='b-statistics__table-row')
    
    for row in rows:
        cols = row.find_all('td')
        
        # A valid fighter row should have at least 10 columns
        if len(cols) < 10:
            continue
            
        # Extract Fighter URL from the first name tag
        first_name_tag = cols[0].find('a')
        fighter_url = first_name_tag['href'] if first_name_tag and 'href' in first_name_tag.attrs else ""
        
        # Determine if the fighter has a championship belt icon
        is_champion = False
        if len(cols) > 10:
            belt_img = cols[10].find('img')
            if belt_img:
                is_champion = True

        # Extract textual data
        fighter = {
            'fighter_url': fighter_url,
            'first_name': clean_text(cols[0].text),
            'last_name': clean_text(cols[1].text),
            'nickname': clean_text(cols[2].text),
            'height': clean_text(cols[3].text),
            'weight': clean_text(cols[4].text),
            'reach': clean_text(cols[5].text),
            'stance': clean_text(cols[6].text),
            'wins': clean_text(cols[7].text),
            'losses': clean_text(cols[8].text),
            'draws': clean_text(cols[9].text),
            'is_champion': is_champion
        }
        
        fighters_data.append(fighter)
        
    return fighters_data

def main():
    all_fighters = []
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
        )
        page = context.new_page()
        
        # Iterate through alphabet a-z
        letters = string.ascii_lowercase
        
        for letter in letters:
            target_url = FIGHTERS_BASE_URL.format(letter)
            logging.info(f"Scraping fighters starting with '{letter.upper()}': {target_url}")
            
            soup = get_soup(target_url, page)
            if soup:
                page_data = parse_fighters_page(soup)
                logging.info(f"Found {len(page_data)} fighters for letter '{letter.upper()}'.")
                all_fighters.extend(page_data)
            
            # Polite scraping pause between large page loads
            time.sleep(2 + random.uniform(0.5, 1.5))
                
        browser.close()
            
    # Compile and Export Data
    if all_fighters:
        os.makedirs('./data', exist_ok=True)
        df = pd.DataFrame(all_fighters)
        
        # Optional: Convert string numbers to numeric where appropriate
        for col in ['wins', 'losses', 'draws']:
            df[col] = pd.to_numeric(df[col], errors='coerce')
        
        csv_filename = './data/ufc_fighters.csv'
        df.to_csv(csv_filename, index=False)
        
        logging.info(f"Data successfully saved to {csv_filename}")
        logging.info(f"Total fighters extracted: {len(df)}")
        
        print("\n--- DataFrame Snapshot ---")
        print(df.head())
    else:
        logging.warning("No data extracted. Check your connection or the target website structure.")

if __name__ == "__main__":
    main()

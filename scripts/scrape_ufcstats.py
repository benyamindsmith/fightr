from playwright.sync_api import sync_playwright
from bs4 import BeautifulSoup
import pandas as pd
import time
import re
import string
import os

def get_fighter_links(letter, page):
    url = f"http://www.ufcstats.com/statistics/fighters?char={letter}&page=all"
    
    # Go to the URL and wait until the network is mostly idle
    page.goto(url, wait_until="domcontentloaded")
    
    # CRITICAL: Wait for the actual fighter links to appear. 
    # If the JS challenge is running, this forces the script to wait until it passes and reloads.
    try:
        page.wait_for_selector('a[href*="/fighter-details/"]', timeout=20000)
    except Exception as e:
        print(f"  [!] Timeout waiting for links on letter {letter}. Might be blocked or no fighters.")
        return []

    soup = BeautifulSoup(page.content(), 'html.parser')
    
    links = []
    seen = set()
    
    for a_tag in soup.find_all('a', href=re.compile(r'/fighter-details/')):
        href = a_tag['href']
        
        if href.startswith('http'):
            full_url = href.replace('http://ufcstats.com', 'http://www.ufcstats.com')
        else:
            full_url = 'http://www.ufcstats.com' + href
            
        if full_url not in seen:
            seen.add(full_url)
            links.append(full_url)

    return links

def parse_fighter_details(url, page):
    page.goto(url, wait_until="domcontentloaded")
    
    # Wait for the fighter's name to render to ensure we passed any secondary bot checks
    page.wait_for_selector('.b-content__title-highlight', timeout=15000)
    
    soup = BeautifulSoup(page.content(), 'html.parser')
    
    fighter_data = {
        'Name': None, 'Wins': 0, 'Losses': 0, 'Draws': 0, 'NC': 0,
        'Height': None, 'Weight': None, 'Reach': None, 'STANCE': None, 'DOB': None,
        'SLpM': None, 'Str. Acc.': None, 'SApM': None, 'Str. Def.': None,
        'TD Avg.': None, 'TD Acc.': None, 'TD Def.': None, 'Sub. Avg.': None
    }
    
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
    
    stat_map = {
        'Height': 'Height', 'Weight': 'Weight', 'Reach': 'Reach',
        'STANCE': 'STANCE', 'DOB': 'DOB', 'SLpM': 'SLpM',
        'Str. Acc.': 'Str. Acc.', 'SApM': 'SApM', 'Str. Def': 'Str. Def.',
        'TD Avg.': 'TD Avg.', 'TD Acc.': 'TD Acc.', 'TD Def.': 'TD Def.',
        'Sub. Avg.': 'Sub. Avg.'
    }
    
    for item in list_items:
        strings = list(item.stripped_strings)
        if len(strings) >= 1:
            title = strings[0].replace(':', '').strip()
            value = strings[1] if len(strings) > 1 else None
            
            if title in stat_map:
                final_key = stat_map[title]
                fighter_data[final_key] = None if value in ['--', None] else value

    return fighter_data

def scrape_all_fighters(letters_to_scrape='a'):
    all_fighters = []
    
    # Start the Playwright browser session
    with sync_playwright() as p:
        # Launch browser. Set headless=False if you want to visibly watch it work!
        browser = p.chromium.launch(headless=True) 
        
        # Adding a real user agent helps prevent getting flagged
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        )
        page = context.new_page()

        for letter in letters_to_scrape:
            print(f"Fetching links for '{letter.upper()}'...")
            try:
                fighter_links = get_fighter_links(letter, page)
                print(f"  Found {len(fighter_links)} fighters for '{letter.upper()}'")
            except Exception as e:
                print(f"  Error fetching links for '{letter.upper()}': {e}")
                continue

            for i, link in enumerate(fighter_links):
                print(f"  Scraping fighter {i+1}/{len(fighter_links)}: {link}")
                try:
                    data = parse_fighter_details(link, page)
                    all_fighters.append(data)
                except Exception as e:
                    print(f"  Error scraping {link}: {e}")

                time.sleep(0.5) # Still good practice to be polite to the server
                
        browser.close()
            
    df = pd.DataFrame(all_fighters)
    return df

if __name__ == "__main__":
    test_letters = string.ascii_lowercase 
    
    print("Starting scraper...")
    df_fighters = scrape_all_fighters(letters_to_scrape=test_letters)
    
    os.makedirs('./data', exist_ok=True)
    csv_filename = './data/ufcstats_data.csv'
    
    df_fighters.to_csv(csv_filename, index=False)
    print(f"Saved to {csv_filename}")

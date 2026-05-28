import requests
from bs4 import BeautifulSoup
import pandas as pd
import time
import re
import string

def get_fighter_links(letter):
    url = f"http://ufcstats.com/statistics/fighters?char={letter}&page=all"
    headers = {'User-Agent': 'Mozilla/5.0'}
    response = requests.get(url, headers=headers)
    soup = BeautifulSoup(response.text, 'html.parser')
    
    links = []
    seen = set()
    # Each row has multiple <a> tags pointing to the same fighter-details URL; deduplicate
    for a_tag in soup.find_all('a', href=re.compile(r'/fighter-details/')):
        href = a_tag['href']
        if href.startswith('http'):
            full_url = href
        else:
            full_url = 'http://ufcstats.com' + href
        if full_url not in seen:
            seen.add(full_url)
            links.append(full_url)

    return links

def parse_fighter_details(url):
    headers = {'User-Agent': 'Mozilla/5.0'}
    response = requests.get(url, headers=headers)
    soup = BeautifulSoup(response.text, 'html.parser')
    
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

def scrape_all_fighters(letters_to_scrape='a'):
    all_fighters = []
    
    for letter in letters_to_scrape:
        print(f"Fetching links for '{letter.upper()}'...")
        fighter_links = get_fighter_links(letter)
        
        for i, link in enumerate(fighter_links):
            print(f"Scraping fighter {i+1}/{len(fighter_links)}: {link}")
            try:
                data = parse_fighter_details(link)
                all_fighters.append(data)
            except Exception as e:
                print(f"Error scraping {link}: {e}")
                
            time.sleep(0.5) 
            
    df = pd.DataFrame(all_fighters)
    return df

if __name__ == "__main__":
    # Change test_letters to string.ascii_lowercase to run the full alphabet
    test_letters = string.ascii_lowercase 
    
    print("Starting scraper...")
    df_fighters = scrape_all_fighters(letters_to_scrape=test_letters)
    
    csv_filename = './data/ufcstats_data.csv'
    df_fighters.to_csv(csv_filename, index=False)
    print(f"Saved to {csv_filename}")

import requests
from bs4 import BeautifulSoup
import pandas as pd
import time

# The endpoint UFC uses to load fighters dynamically
AJAX_URL = 'https://www.ufc.com/views/ajax?_wrapper_format=drupal_ajax'

def get_fighter_stats(profile_url):
    """
    Visits an individual fighter's profile to extract deep stats and bio information.
    """
    if not profile_url:
        return {}
    
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
    stats = {}
    
    try:
        response = requests.get(profile_url, headers=headers)
        if response.status_code != 200:
            return stats
            
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # 1. Grab Bio Fields (Age, Height, Weight, Reach, Octagon Debut)
        bio_fields = soup.find_all('div', class_='c-bio__field')
        for field in bio_fields:
            label_elem = field.find('div', class_='c-bio__label')
            text_elem = field.find('div', class_='c-bio__text')
            if label_elem and text_elem:
                label = label_elem.text.strip()
                stats[label] = text_elem.text.strip()
                
        # 2. Grab Performance Stats (Striking Accuracy, Takedown Defense, etc.)
        # These are usually located in specific stat overlap blocks
        stat_groups = soup.find_all('div', class_='overlap-wrap')
        for group in stat_groups:
            label_elem = group.find('div', class_='c-overlap__stats-text')
            value_elem = group.find('div', class_='c-overlap__stats-value')
            if label_elem and value_elem:
                label = label_elem.text.strip()
                stats[label] = value_elem.text.strip()

        return stats
        
    except Exception as e:
        print(f"Error fetching stats for {profile_url}: {e}")
        return stats


def scrape_all_ufc_fighters(max_pages=250, scrape_deep_stats=False):
    """
    Loops through the UFC athlete directory.
    - max_pages: Set to ~260 to get all 3100+ fighters (12 per page).
    - scrape_deep_stats: If True, it will visit EVERY fighter's page. (Warning: takes time!)
    """
    all_fighters = []
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
    
    print("Starting UFC Roster Scrape...")
    
    for page in range(max_pages):
        payload = {
            'view_name': 'all_athletes',
            'view_display_id': 'page',
            'view_args': '',
            'view_path': '/athletes/all',
            'view_base_path': '',
            'page': page
        }
        
        response = requests.post(AJAX_URL, data=payload, headers=headers)
        if response.status_code != 200:
            print(f"Stopping at page {page} - Server returned {response.status_code}")
            break
            
        data = response.json()
        html_content = ""
        
        # The UFC API returns JSON commands; we need the one that 'inserts' HTML
        for item in data:
            if item.get('command') == 'insert':
                html_content = item.get('data', '')
                break
                
        if not html_content:
            print(f"No more HTML content found at page {page}. Scraping finished.")
            break
            
        soup = BeautifulSoup(html_content, 'html.parser')
        fighter_blocks = soup.find_all('li', class_='l-flex__item')
        
        if not fighter_blocks:
            break
            
        for block in fighter_blocks:
            fighter = {}
            
            # --- EXTRACT BASIC DIRECTORY INFO ---
            name_elem = block.find('span', class_='c-listing-athlete__name')
            fighter['Name'] = name_elem.text.strip() if name_elem else None
            
            nickname_elem = block.find('span', class_='c-listing-athlete__nickname')
            fighter['Nickname'] = nickname_elem.text.strip().replace('"', '') if nickname_elem else None
            
            weight_elem = block.find('span', class_='c-listing-athlete__title')
            fighter['Weight Class'] = weight_elem.text.strip() if weight_elem else None
            
            record_elem = block.find('span', class_='c-listing-athlete__record')
            fighter['Record'] = record_elem.text.strip() if record_elem else None
            
            link_elem = block.find('a')
            profile_url = 'https://www.ufc.com' + link_elem.get('href') if link_elem and link_elem.get('href') else None
            fighter['URL'] = profile_url
            
            # --- EXTRACT DEEP STATS (OPTIONAL) ---
            if scrape_deep_stats and profile_url:
                deep_stats = get_fighter_stats(profile_url)
                fighter.update(deep_stats)
                time.sleep(0.5) # Sleep to avoid rate-limiting on individual pages
                
            all_fighters.append(fighter)
            
        print(f"Successfully scraped page {page} ({len(fighter_blocks)} fighters)")
        time.sleep(1) # Be polite to the UFC servers
        
    # Convert list of dictionaries to Pandas DataFrame
    df = pd.DataFrame(all_fighters)
    return df

if __name__ == "__main__":
    # NOTE: Set scrape_deep_stats=True to go into every fighter's profile.
    # Set max_pages to a lower number (e.g., 5) to test it first.
    ufc_df = scrape_all_ufc_fighters(max_pages=300, scrape_deep_stats=True)
    
    # Save as CSV
    csv_filename = './data/ufc_athletes.csv'
    ufc_df.to_csv(csv_filename, index=False)
    print(f"Saved to {csv_filename}")
    
    # Save as .RData
    rdata_filename = './data/ufc_athletes.RData'
    # df_name is the variable name that will appear in R when you run load("ufc_fighters_data.RData")
    pyreadr.write_rdata(rdata_filename, ufc_df, df_name='ufc_athletes')
    print(f"Saved to {rdata_filename}")

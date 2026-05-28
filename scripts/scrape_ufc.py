import os
import re
import time
import random
import logging
import pandas as pd
from bs4 import BeautifulSoup
from urllib.parse import urljoin
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

# Set up logging
logging.basicConfig(
    level=logging.INFO, 
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

BASE_URL = "https://www.ufc.com"
OUTPUT_DIR = "./data"
CSV_FILENAME = os.path.join(OUTPUT_DIR, "ufc_athletes.csv")
os.makedirs(OUTPUT_DIR, exist_ok=True)

def clean_text(value):
    """Normalize whitespace."""
    if value is None:
        return None
    return re.sub(r"\s+", " ", value).strip()

def extract_text_by_possible_labels(soup, labels):
    """Fallback parser for raw text extraction."""
    results = {}
    lines = [clean_text(line) for line in soup.get_text("\n").split("\n") if clean_text(line)]
    lower_labels = {x.lower() for x in labels}

    for i, line in enumerate(lines):
        normalized_line = line.lower().rstrip(":")
        for label in labels:
            normalized_label = label.lower().rstrip(":")
            if normalized_line == normalized_label and i + 1 < len(lines):
                value = lines[i + 1]
                if value and value.lower() not in lower_labels:
                    results[label] = value
    return results

def get_fighter_bio(profile_url, page, debug=False):
    """Visit an individual UFC fighter profile and extract bio using Playwright."""
    if not profile_url:
        return {}

    try:
        page.goto(profile_url, wait_until="domcontentloaded", timeout=30000)
        # Give dynamic stat blocks a moment to render
        page.wait_for_timeout(random.uniform(1000, 2000))
        html = page.content()
    except PlaywrightTimeoutError:
        logging.error(f"Timeout loading profile: {profile_url}")
        return {}
    except Exception as e:
        logging.error(f"Error loading {profile_url}: {e}")
        return {}

    soup = BeautifulSoup(html, "html.parser")
    stats = {}

    h1 = soup.select_one("h1")
    if h1:
        stats["Profile Name"] = clean_text(h1.get_text(" "))

    nickname_selectors = [
        ".hero-profile__nickname", ".c-hero__headline-suffix", 
        ".field--name-nickname", ".c-bio__nickname",
    ]
    for selector in nickname_selectors:
        elem = soup.select_one(selector)
        if elem:
            stats["Profile Nickname"] = clean_text(elem.get_text(" ")).replace('"', "")
            break

    for field in soup.select(".c-bio__field, .c-bio__field--border-bottom"):
        label_elem = field.select_one(".c-bio__label")
        value_elem = field.select_one(".c-bio__text")
        if label_elem and value_elem:
            key = clean_text(label_elem.get_text(" "))
            value = clean_text(value_elem.get_text(" "))
            if key and value:
                stats[key] = value

    label_value_blocks = soup.select(
        ".c-stat-compare__group, .c-stat-3bar__group, .c-overlap__stats, .overlap-wrap"
    )
    for block in label_value_blocks:
        label_elem = block.select_one(".c-overlap__stats-text, .c-stat-compare__label, .c-stat-3bar__label")
        value_elem = block.select_one(".c-overlap__stats-value, .c-stat-compare__number, .c-stat-3bar__value")
        if label_elem and value_elem:
            key = clean_text(label_elem.get_text(" "))
            value = clean_text(value_elem.get_text(" "))
            if key and value:
                stats[key] = value

    wanted_labels = [
        "Age", "Height", "Weight", "Reach", "Leg reach", 
        "Leg Reach", "Octagon Debut", "Place of Birth", 
        "Fighting style", "Fighting Style", "Trains at", 
        "Trains At", "Status",
    ]
    fallback = extract_text_by_possible_labels(soup, wanted_labels)
    for key, value in fallback.items():
        stats.setdefault(key, value)

    return stats

def parse_roster_card(card):
    """Extract basic fighter info from one UFC roster card."""
    fighter = {}
    name_elem = card.select_one(".c-listing-athlete__name")
    fighter["Name"] = clean_text(name_elem.get_text(" ")) if name_elem else None

    nickname_elem = card.select_one(".c-listing-athlete__nickname")
    fighter["Nickname"] = clean_text(nickname_elem.get_text(" ")).replace('"', "") if nickname_elem else None

    weight_elem = card.select_one(".c-listing-athlete__title")
    fighter["Weight Class"] = clean_text(weight_elem.get_text(" ")) if weight_elem else None

    record_elem = card.select_one(".c-listing-athlete__record")
    fighter["Record"] = clean_text(record_elem.get_text(" ")) if record_elem else None

    link_elem = card.select_one("a[href*='/athlete/']")
    href = link_elem.get("href") if link_elem else None
    fighter["URL"] = urljoin(BASE_URL, href) if href else None

    return fighter

def scrape_all_ufc_fighters():
    all_fighters = []
    seen_urls = set()

    with sync_playwright() as p:
        # Launch browser. In GitHub actions, this runs headlessly by default.
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
        )
        page = context.new_page()

        logging.info("Loading UFC roster page...")
        page.goto(f"{BASE_URL}/athletes/all", wait_until="domcontentloaded")

        # Handle potential cookie banners obscuring the button
        try:
            accept_btn = page.locator("button:has-text('Accept'), button#onetrust-accept-btn-handler")
            if accept_btn.is_visible(timeout=3000):
                accept_btn.click()
        except:
            pass

        # Click "Load More" repeatedly
        click_count = 0
        while True:
            # The 'Load More' link usually has an 'a' tag with class 'button' 
            load_more_btn = page.locator("a.button:has-text('Load More'), li.pager__item a:has-text('Load More')").first
            
            if load_more_btn.is_visible():
                try:
                    load_more_btn.scroll_into_view_if_needed()
                    load_more_btn.click()
                    click_count += 1
                    logging.info(f"Clicked 'Load More' ({click_count})")
                    # Wait for new items to render into the DOM
                    page.wait_for_timeout(2500)
                except Exception as e:
                    logging.warning(f"Failed to click 'Load More': {e}")
                    break
            else:
                logging.info("No more 'Load More' button visible. Assuming all fighters are loaded.")
                break

        # Extract all HTML once fully loaded
        html = page.content()
        soup = BeautifulSoup(html, "html.parser")
        possible_cards = soup.select("li.l-flex__item, .view-athletes .views-row, .c-listing-athlete")
        cards = [card for card in possible_cards if card.select_one(".c-listing-athlete__name")]

        logging.info(f"Found {len(cards)} fighter cards on the master page. Extracting URLs...")

        roster = []
        for card in cards:
            fighter = parse_roster_card(card)
            url_key = fighter.get("URL")
            if url_key and url_key not in seen_urls:
                seen_urls.add(url_key)
                roster.append(fighter)

        logging.info(f"Beginning deep scrape for {len(roster)} fighters...")

        # Deep scrape per fighter
        for i, fighter in enumerate(roster, 1):
            profile_url = fighter.get("URL")
            if profile_url:
                deep_stats = get_fighter_bio(profile_url, page)
                fighter.update(deep_stats)
                
            all_fighters.append(fighter)
            if i % 10 == 0:
                logging.info(f"Progress: {i} / {len(roster)} scraped.")

        browser.close()

    df = pd.DataFrame(all_fighters)
    df = df.dropna(axis=1, how="all")
    return df

if __name__ == "__main__":
    ufc_df = scrape_all_ufc_fighters()
    logging.info(f"\nRows scraped: {len(ufc_df)}")
    
    ufc_df.to_csv(CSV_FILENAME, index=False)
    logging.info(f"Saved CSV to {CSV_FILENAME}")

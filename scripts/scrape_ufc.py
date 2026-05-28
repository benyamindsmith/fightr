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


BASE_URL = "https://www.ufc.com"
OUTPUT_DIR = "./data"
CSV_FILENAME = os.path.join(OUTPUT_DIR, "ufc_athletes.csv")
RDATA_FILENAME = os.path.join(OUTPUT_DIR, "ufc_athletes.RData")

os.makedirs(OUTPUT_DIR, exist_ok=True)


HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Connection": "keep-alive",
}


def clean_text(value):
    """Normalize whitespace."""
    if value is None:
        return None
    return re.sub(r"\s+", " ", value).strip()


def request_soup(url, session, retries=3, timeout=25):
    """
    Fetch a URL and return BeautifulSoup.
    Retries on temporary server errors.
    """
    last_error = None

    for attempt in range(1, retries + 1):
        try:
            response = session.get(url, headers=HEADERS, timeout=timeout)

            if response.status_code == 200:
                return BeautifulSoup(response.text, "html.parser")

            print(f"Request failed: {response.status_code} | {url}")

            # Retry only on server-side/rate-limit-ish responses
            if response.status_code in [429, 500, 502, 503, 504]:
                sleep_for = attempt * 2 + random.uniform(0.5, 1.5)
                time.sleep(sleep_for)
                continue

            return None

        except Exception as e:
            last_error = e
            print(f"Request error on attempt {attempt}: {e} | {url}")
            time.sleep(attempt * 2)

    print(f"Giving up on {url}. Last error: {last_error}")
    return None


def extract_text_by_possible_labels(soup, labels):
    """
    Fallback parser:
    Searches page text for lines like:

    Reach
    70.00

    or

    Octagon Debut
    Apr. 10, 2016
    """
    results = {}
    lines = [
        clean_text(line)
        for line in soup.get_text("\n").split("\n")
        if clean_text(line)
    ]

    for i, line in enumerate(lines):
        normalized_line = line.lower().rstrip(":")
        for label in labels:
            normalized_label = label.lower().rstrip(":")
            if normalized_line == normalized_label and i + 1 < len(lines):
                value = lines[i + 1]
                if value and value.lower() not in [x.lower() for x in labels]:
                    results[label] = value

    return results


def get_fighter_bio(profile_url, session, debug=False):
    """
    Visit an individual UFC fighter profile and extract bio/deep profile fields.
    """
    if not profile_url:
        return {}

    soup = request_soup(profile_url, session=session)
    if soup is None:
        return {}

    if debug:
        with open("debug_profile.html", "w", encoding="utf-8") as f:
            f.write(str(soup))
        print("Saved debug_profile.html")

    stats = {}

    # Profile name
    h1 = soup.select_one("h1")
    if h1:
        stats["Profile Name"] = clean_text(h1.get_text(" "))

    # Nickname - UFC markup can vary
    nickname_selectors = [
        ".hero-profile__nickname",
        ".c-hero__headline-suffix",
        ".field--name-nickname",
        ".c-bio__nickname",
    ]

    for selector in nickname_selectors:
        elem = soup.select_one(selector)
        if elem:
            stats["Profile Nickname"] = clean_text(elem.get_text(" ")).replace('"', "")
            break

    # Main bio fields
    # Common UFC structure:
    # div.c-bio__field
    #   div.c-bio__label
    #   div.c-bio__text
    for field in soup.select(".c-bio__field, .c-bio__field--border-bottom"):
        label_elem = field.select_one(".c-bio__label")
        value_elem = field.select_one(".c-bio__text")

        if label_elem and value_elem:
            key = clean_text(label_elem.get_text(" "))
            value = clean_text(value_elem.get_text(" "))
            if key and value:
                stats[key] = value

    # Some stat blocks use other class names
    label_value_blocks = soup.select(
        ".c-stat-compare__group, "
        ".c-stat-3bar__group, "
        ".c-overlap__stats, "
        ".overlap-wrap"
    )

    for block in label_value_blocks:
        label_elem = block.select_one(
            ".c-overlap__stats-text, "
            ".c-stat-compare__label, "
            ".c-stat-3bar__label"
        )
        value_elem = block.select_one(
            ".c-overlap__stats-value, "
            ".c-stat-compare__number, "
            ".c-stat-3bar__value"
        )

        if label_elem and value_elem:
            key = clean_text(label_elem.get_text(" "))
            value = clean_text(value_elem.get_text(" "))
            if key and value:
                stats[key] = value

    # Text fallback for the specific UFC bio fields you care about
    wanted_labels = [
        "Age",
        "Height",
        "Weight",
        "Reach",
        "Leg reach",
        "Leg Reach",
        "Octagon Debut",
        "Place of Birth",
        "Fighting style",
        "Fighting Style",
        "Trains at",
        "Trains At",
        "Status",
    ]

    fallback = extract_text_by_possible_labels(soup, wanted_labels)

    # Merge fallback without overwriting good selector results
    for key, value in fallback.items():
        stats.setdefault(key, value)

    return stats


def parse_roster_card(card):
    """
    Extract basic fighter info from one UFC roster card.
    """
    fighter = {}

    name_elem = card.select_one(".c-listing-athlete__name")
    fighter["Name"] = clean_text(name_elem.get_text(" ")) if name_elem else None

    nickname_elem = card.select_one(".c-listing-athlete__nickname")
    fighter["Nickname"] = (
        clean_text(nickname_elem.get_text(" ")).replace('"', "")
        if nickname_elem
        else None
    )

    weight_elem = card.select_one(".c-listing-athlete__title")
    fighter["Weight Class"] = clean_text(weight_elem.get_text(" ")) if weight_elem else None

    record_elem = card.select_one(".c-listing-athlete__record")
    fighter["Record"] = clean_text(record_elem.get_text(" ")) if record_elem else None

    link_elem = card.select_one("a[href*='/athlete/']")
    href = link_elem.get("href") if link_elem else None
    fighter["URL"] = urljoin(BASE_URL, href) if href else None

    return fighter


def scrape_roster_page(page_num, session):
    """
    Scrape one UFC roster page.

    Uses:
    https://www.ufc.com/athletes/all?page=0
    https://www.ufc.com/athletes/all?page=1
    etc.
    """
    url = f"{BASE_URL}/athletes/all?page={page_num}"
    soup = request_soup(url, session=session)

    if soup is None:
        return []

    # UFC athlete cards are usually li.l-flex__item containing c-listing-athlete__name
    possible_cards = soup.select("li.l-flex__item, .view-athletes .views-row, .c-listing-athlete")

    cards = []
    for card in possible_cards:
        if card.select_one(".c-listing-athlete__name"):
            cards.append(card)

    # De-duplicate cards by profile URL
    fighters = []
    seen_urls = set()

    for card in cards:
        fighter = parse_roster_card(card)

        if not fighter.get("Name") and not fighter.get("URL"):
            continue

        url_key = fighter.get("URL") or fighter.get("Name")
        if url_key in seen_urls:
            continue

        seen_urls.add(url_key)
        fighters.append(fighter)

    return fighters


def scrape_all_ufc_fighters(
    max_pages=300,
    scrape_deep_stats=True,
    delay_between_pages=1.0,
    delay_between_profiles=0.5,
    stop_after_empty_pages=3,
):
    """
    Scrape UFC athletes.

    max_pages:
        Number of roster pages to try.

    scrape_deep_stats:
        If True, visits every individual athlete page.

    stop_after_empty_pages:
        Stops after this many consecutive empty roster pages.
    """
    all_fighters = []
    seen_urls = set()
    empty_pages = 0

    session = requests.Session()

    print("Starting UFC roster scrape...")

    for page in range(max_pages):
        fighters_on_page = scrape_roster_page(page, session=session)

        if not fighters_on_page:
            empty_pages += 1
            print(f"No fighters found on page {page}. Empty streak: {empty_pages}")

            if empty_pages >= stop_after_empty_pages:
                print("Stopping because multiple empty pages were found.")
                break

            time.sleep(delay_between_pages)
            continue

        empty_pages = 0

        new_count = 0

        for fighter in fighters_on_page:
            profile_url = fighter.get("URL")

            if profile_url and profile_url in seen_urls:
                continue

            if profile_url:
                seen_urls.add(profile_url)

            if scrape_deep_stats and profile_url:
                deep_stats = get_fighter_bio(profile_url, session=session)
                fighter.update(deep_stats)

                time.sleep(delay_between_profiles + random.uniform(0.1, 0.4))

            all_fighters.append(fighter)
            new_count += 1

        print(
            f"Page {page}: found {len(fighters_on_page)} fighters, "
            f"added {new_count}, total {len(all_fighters)}"
        )

        time.sleep(delay_between_pages + random.uniform(0.2, 0.8))

    df = pd.DataFrame(all_fighters)

    # Optional cleanup: remove completely empty columns
    df = df.dropna(axis=1, how="all")

    return df


def test_single_fighter():
    """
    Test parser on Dong Hyun Ma first.
    """
    session = requests.Session()
    url = "https://www.ufc.com/athlete/dong-hyun-ma"

    stats = get_fighter_bio(url, session=session, debug=True)

    print("\nSingle fighter test:")
    print("-" * 60)
    for key, value in stats.items():
        print(f"{key}: {value}")


if __name__ == "__main__":
    # Step 1: Test one fighter first.
    # This creates debug_profile.html so you can inspect the exact UFC HTML.
    test_single_fighter()

    # Step 2: Run the full scrape.
    # Start smaller while testing, e.g. max_pages=5.
    ufc_df = scrape_all_ufc_fighters(
        max_pages=300,
        scrape_deep_stats=True,
        delay_between_pages=1.0,
        delay_between_profiles=0.5,
    )

    print("\nPreview:")
    print(ufc_df.head())
    print("\nColumns:")
    print(list(ufc_df.columns))
    print(f"\nRows scraped: {len(ufc_df)}")

    # Save CSV
    ufc_df.to_csv(CSV_FILENAME, index=False)
    print(f"Saved CSV to {CSV_FILENAME}")

    # Save RData
    if HAS_PYREADR:
        pyreadr.write_rdata(RDATA_FILENAME, ufc_df, df_name="ufc_athletes")
        print(f"Saved RData to {RDATA_FILENAME}")
    else:
        print(
            "Skipped RData export because pyreadr is not installed. "
            "Install it with: pip install pyreadr"
        )

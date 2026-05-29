#' UFC Athlete Profiles and Career Statistics
#'
#' A dataset containing UFC athlete-level profile information, career records,
#' physical attributes, fighting styles, gym affiliations, and summarized
#' performance statistics. Each row represents one athlete listed on the UFC
#' athlete profile pages.
#'
#' The dataset combines biographical information, official UFC profile fields,
#' striking and grappling statistics, fight outcome summaries, and win-method
#' breakdowns. Some fields may be missing when the information is unavailable
#' from the source profile or when an athlete has limited UFC activity.
#'
#' @format A data frame with variables:
#' \describe{
#'   \item{name}{Character. Athlete name as listed in the dataset.}
#'   \item{nickname}{Character. Athlete nickname, where available.}
#'   \item{weight_class}{Character. Athlete's listed UFC weight class.}
#'   \item{url}{Character. URL for the athlete's UFC profile page.}
#'   \item{profile_name}{Character. Athlete name as shown on the UFC profile page.}
#'   \item{profile_nickname}{Character. Athlete nickname as shown on the UFC profile page, where available.}
#'   \item{status}{Character. Athlete status, such as `"Active"` or `"Not Fighting"`.}
#'   \item{place_of_birth}{Character. Athlete's listed place of birth.}
#'   \item{age}{Numeric. Athlete age in years, where available.}
#'   \item{height}{Numeric. Athlete height in inches, where available.}
#'   \item{weight}{Numeric. Athlete listed weight in pounds, where available.}
#'   \item{octagon_debut}{Date. Date of the athlete's UFC debut, where available.}
#'   \item{sig_strikes_landed}{Numeric. Total significant strikes landed in UFC competition.}
#'   \item{sig_strikes_attempted}{Numeric. Total significant strikes attempted in UFC competition.}
#'   \item{sig_str_landed}{Numeric. Significant strikes landed per minute.}
#'   \item{sig_str_absorbed}{Numeric. Significant strikes absorbed per minute.}
#'   \item{takedown_avg}{Numeric. Average takedowns landed per 15 minutes.}
#'   \item{submission_avg}{Numeric. Average submission attempts per 15 minutes.}
#'   \item{sig_str_defense}{Numeric. Significant strike defense rate, expressed as a proportion.}
#'   \item{takedown_defense}{Numeric. Takedown defense rate, expressed as a proportion.}
#'   \item{knockdown_avg}{Numeric. Average knockdowns landed per 15 minutes.}
#'   \item{average_fight_time}{Period. Athlete's average UFC fight time, where available.}
#'   \item{takedowns_attempted}{Numeric. Total takedown attempts in UFC competition, where available.}
#'   \item{fighting_style}{Character. Athlete's listed fighting style, where available.}
#'   \item{reach}{Numeric. Athlete reach in inches, where available.}
#'   \item{leg_reach}{Numeric. Athlete leg reach in inches, where available.}
#'   \item{takedowns_landed}{Numeric. Total takedowns landed in UFC competition, where available.}
#'   \item{trains_at}{Character. Athlete's listed gym or training affiliation, where available.}
#'   \item{wins}{Character. Athlete's listed career wins.}
#'   \item{losses}{Character. Athlete's listed career losses.}
#'   \item{draws}{Character. Athlete's listed career draws.}
#'   \item{standing_count}{Numeric. Number of significant strikes landed at distance.}
#'   \item{standing_pct}{Numeric. Proportion of significant strikes landed at distance.}
#'   \item{clinch_count}{Numeric. Number of significant strikes landed in the clinch.}
#'   \item{clinch_percent}{Numeric. Proportion of significant strikes landed in the clinch.}
#'   \item{ground_count}{Numeric. Number of significant strikes landed on the ground.}
#'   \item{ground_percent}{Numeric. Proportion of significant strikes landed on the ground.}
#'   \item{ko_tko_win}{Numeric. Number of wins by knockout or technical knockout.}
#'   \item{ko_tko_percent}{Numeric. Proportion of wins by knockout or technical knockout.}
#'   \item{dec_wins}{Numeric. Number of wins by decision.}
#'   \item{dec_percent}{Numeric. Proportion of wins by decision.}
#'   \item{sub_wins}{Numeric. Number of wins by submission.}
#'   \item{sub_percent}{Numeric. Proportion of wins by submission.}
#' }
#'
#' @source UFC athlete profiles, \url{https://www.ufc.com/athletes}
#' @name ufc_athletes
#' @docType data
NULL

#' UFC Fight Results and Event Metadata
#'
#' A dataset containing UFC fight-level information, including event details,
#' fighter names, fight outcomes, weight classes, methods of victory, round and
#' time information, referees, and selected judging details. Each row represents
#' one scheduled or completed UFC bout.
#'
#' The dataset includes both historical fights and scheduled future bouts. For
#' future or incomplete fights, result-related fields such as winner, method,
#' round, time, referee, and judging details may be missing.
#'
#' @format A data frame with 17 variables:
#' \describe{
#'   \item{fight_url}{Character. URL for the fight details page on UFCStats.}
#'   \item{event_name_succ}{Numeric. Number of successful strikes or actions associated with the event name field, if parsed from source tables. Often missing.}
#'   \item{event_name_att}{Numeric. Number of attempted strikes or actions associated with the event name field, if parsed from source tables. Often missing.}
#'   \item{date}{Date. Date of the UFC event.}
#'   \item{location}{Character. Event location, usually formatted as city and country or city and state.}
#'   \item{f1_name}{Character. Name of the first listed fighter.}
#'   \item{f1_result}{Character. Result for the first listed fighter, typically `"W"` for win or `"L"` for loss. Missing for scheduled or incomplete bouts.}
#'   \item{f2_name}{Character. Name of the second listed fighter.}
#'   \item{f2_result}{Character. Result for the second listed fighter, typically `"W"` for win or `"L"` for loss. Missing for scheduled or incomplete bouts.}
#'   \item{weight_class}{Character. Weight class or bout category, such as `"Bantamweight Bout"` or `"Heavyweight Bout"`.}
#'   \item{method}{Character. Method of victory, such as `"Decision - Unanimous"`, `"KO/TKO"`, or `"Submission"`. Missing for scheduled or incomplete bouts.}
#'   \item{round}{Numeric. Round in which the fight ended. Missing for scheduled or incomplete bouts.}
#'   \item{time}{Period. Time elapsed in the final round when the fight ended. Missing for scheduled or incomplete bouts.}
#'   \item{time_format}{Character. Scheduled fight format, such as `"3 Rnd (5-5-5)"` or `"5 Rnd (5-5-5-5-5)"`.}
#'   \item{referee}{Character. Name of the referee. Missing for scheduled or incomplete bouts.}
#'   \item{judging_details_succ}{Numeric. Successful or winning-side judging detail extracted from the source, where available. Often missing for non-decision fights or incomplete bouts.}
#'   \item{judging_details_att}{Numeric. Attempted or opposing-side judging detail extracted from the source, where available. Often missing for non-decision fights or incomplete bouts.}
#' }
#'
#' @source UFCStats, \url{http://www.ufcstats.com/}
#' @name ufc_fights
#' @docType data
NULL

#' future or incomplete fights, result-related fields such as winner, method,
#' round, time, referee, and judging details may be missing.
#'
#' @format A data frame with 17 variables:
#' \describe{
#'   \item{fight_url}{Character. URL for the fight details page on UFCStats.}
#'   \item{event_name_succ}{Numeric. Number of successful strikes or actions associated with the event name field, if parsed from source tables. Often missing.}
#'   \item{event_name_att}{Numeric. Number of attempted strikes or actions associated with the event name field, if parsed from source tables. Often missing.}
#'   \item{date}{Date. Date of the UFC event.}
#'   \item{location}{Character. Event location, usually formatted as city and country or city and state.}
#'   \item{f1_name}{Character. Name of the first listed fighter.}
#'   \item{f1_result}{Character. Result for the first listed fighter, typically `"W"` for win or `"L"` for loss. Missing for scheduled or incomplete bouts.}
#'   \item{f2_name}{Character. Name of the second listed fighter.}
#'   \item{f2_result}{Character. Result for the second listed fighter, typically `"W"` for win or `"L"` for loss. Missing for scheduled or incomplete bouts.}
#'   \item{weight_class}{Character. Weight class or bout category, such as `"Bantamweight Bout"` or `"Heavyweight Bout"`.}
#'   \item{method}{Character. Method of victory, such as `"Decision - Unanimous"`, `"KO/TKO"`, or `"Submission"`. Missing for scheduled or incomplete bouts.}
#'   \item{round}{Numeric. Round in which the fight ended. Missing for scheduled or incomplete bouts.}
#'   \item{time}{Period. Time elapsed in the final round when the fight ended. Missing for scheduled or incomplete bouts.}
#'   \item{time_format}{Character. Scheduled fight format, such as `"3 Rnd (5-5-5)"` or `"5 Rnd (5-5-5-5-5)"`.}
#'   \item{referee}{Character. Name of the referee. Missing for scheduled or incomplete bouts.}
#'   \item{judging_details_succ}{Numeric. Successful or winning-side judging detail extracted from the source, where available. Often missing for non-decision fights or incomplete bouts.}
#'   \item{judging_details_att}{Numeric. Attempted or opposing-side judging detail extracted from the source, where available. Often missing for non-decision fights or incomplete bouts.}
#' }
#'
#' @source UFCStats, \url{http://www.ufcstats.com/}
#' @name ufc_fights
#' @docType data
NULL



#' UFCStats Fighter Records and Performance Metrics
#'
#' A dataset containing fighter-level records, physical attributes, stance,
#' birth dates, and summarized performance statistics from UFCStats. Each row
#' represents one fighter listed in the UFCStats fighter database.
#'
#' The dataset includes career record information, biometric measurements, and
#' commonly reported UFCStats striking and grappling metrics. Missing values
#' indicate that the field was unavailable or not reported by the source.
#'
#' @format A data frame with 18 variables:
#' \describe{
#'   \item{name}{Character. Fighter name as listed on UFCStats.}
#'   \item{wins}{Numeric. Number of career wins listed for the fighter.}
#'   \item{losses}{Numeric. Number of career losses listed for the fighter.}
#'   \item{draws}{Numeric. Number of career draws listed for the fighter.}
#'   \item{nc}{Numeric. Number of no-contest results listed for the fighter.}
#'   \item{height}{Numeric. Fighter height in inches, where available.}
#'   \item{weight}{Numeric. Fighter listed weight in pounds, where available.}
#'   \item{reach}{Numeric. Fighter reach in inches, where available.}
#'   \item{stance}{Character. Fighter stance, such as `"Orthodox"`, `"Southpaw"`, or `"Switch"`, where available.}
#'   \item{dob}{Date. Fighter date of birth, where available.}
#'   \item{s_lp_m}{Numeric. Significant strikes landed per minute.}
#'   \item{str_acc}{Numeric. Significant striking accuracy, expressed as a proportion.}
#'   \item{s_ap_m}{Numeric. Significant strikes absorbed per minute.}
#'   \item{str_def}{Numeric. Significant strike defense, expressed as a proportion.}
#'   \item{td_avg}{Numeric. Average takedowns landed per 15 minutes.}
#'   \item{td_acc}{Numeric. Takedown accuracy, expressed as a proportion.}
#'   \item{td_def}{Numeric. Takedown defense, expressed as a proportion.}
#'   \item{sub_avg}{Numeric. Average submission attempts per 15 minutes.}
#' }
#'
#' @source UFCStats, \url{http://www.ufcstats.com/statistics/fighters}
#' @name ufcstats_data
#' @docType data
NULL

#' Ultimate UFC Dataset
#'
#' A comprehensive, historical dataset of Ultimate Fighting Championship (UFC) bouts
#' sourced from Kaggle. It contains extensive data on fighter demographics, historical
#' performance metrics, physical attributes, bout details, betting odds, and exact
#' fight outcomes. The data is structured from the perspective of the "Red" (R) and
#' "Blue" (B) corners.
#'
#' @format A data frame with 118 variables:
#' \describe{
#'   \item{R_fighter, B_fighter}{The names of the fighters in the Red and Blue corners.}
#'   \item{R_odds, B_odds}{Moneyline betting odds (American format) for each fighter.}
#'   \item{R_ev, B_ev}{Expected value for a $100 wager on each fighter.}
#'   \item{date}{The date the bout took place (YYYY-MM-DD).}
#'   \item{location}{The city, state/province, and country where the event was held.}
#'   \item{country}{The country where the event was held.}
#'   \item{Winner}{The corner that won the bout ("Red" or "Blue").}
#'   \item{title_bout}{Logical; TRUE if the bout was for a championship title.}
#'   \item{weight_class}{The weight division the bout was contested in.}
#'   \item{gender}{The gender category of the bout (MALE or FEMALE).}
#'   \item{no_of_rounds}{The scheduled number of rounds for the bout (typically 3 or 5).}
#'
#'   \item{R_age, B_age}{The age of the fighters at the time of the bout.}
#'   \item{R_Height_cms, B_Height_cms}{Fighter height in centimeters.}
#'   \item{R_Reach_cms, B_Reach_cms}{Fighter reach in centimeters.}
#'   \item{R_Weight_lbs, B_Weight_lbs}{Fighter weigh-in weight in pounds.}
#'   \item{R_Stance, B_Stance}{The fighting stance of the fighter (e.g., Orthodox, Southpaw, Switch).}
#'
#'   \item{R_current_lose_streak, B_current_lose_streak}{Current consecutive losing streak prior to the bout.}
#'   \item{R_current_win_streak, B_current_win_streak}{Current consecutive winning streak prior to the bout.}
#'   \item{R_longest_win_streak, B_longest_win_streak}{Longest winning streak in the fighter's UFC career.}
#'   \item{R_wins, B_wins}{Total historical UFC wins strictly prior to the current bout.}
#'   \item{R_losses, B_losses}{Total historical UFC losses strictly prior to the current bout.}
#'   \item{R_draw, B_draw}{Total historical UFC draws strictly prior to the current bout.}
#'   \item{R_total_rounds_fought, B_total_rounds_fought}{Total number of rounds fought in the UFC prior to the bout.}
#'   \item{R_total_title_bouts, B_total_title_bouts}{Total number of title bouts the fighter has competed in.}
#'
#'   \item{R_avg_SIG_STR_landed, B_avg_SIG_STR_landed}{Average significant strikes landed per minute.}
#'   \item{R_avg_SIG_STR_pct, B_avg_SIG_STR_pct}{Historical significant strike accuracy percentage.}
#'   \item{R_avg_SUB_ATT, B_avg_SUB_ATT}{Average submission attempts per 15 minutes.}
#'   \item{R_avg_TD_landed, B_avg_TD_landed}{Average takedowns landed per 15 minutes.}
#'   \item{R_avg_TD_pct, B_avg_TD_pct}{Historical takedown accuracy percentage.}
#'
#'   \item{R_win_by_Decision_Majority, B_win_by_Decision_Majority}{Career wins by majority decision.}
#'   \item{R_win_by_Decision_Split, B_win_by_Decision_Split}{Career wins by split decision.}
#'   \item{R_win_by_Decision_Unanimous, B_win_by_Decision_Unanimous}{Career wins by unanimous decision.}
#'   \item{`R_win_by_KO/TKO`, `B_win_by_KO/TKO`}{Career wins by knockout or technical knockout.}
#'   \item{R_win_by_Submission, B_win_by_Submission}{Career wins by submission.}
#'   \item{R_win_by_TKO_Doctor_Stoppage, B_win_by_TKO_Doctor_Stoppage}{Career wins by doctor stoppage.}
#'
#'   \item{lose_streak_dif}{Difference in losing streaks (Red minus Blue).}
#'   \item{win_streak_dif}{Difference in winning streaks (Red minus Blue).}
#'   \item{longest_win_streak_dif}{Difference in longest winning streaks (Red minus Blue).}
#'   \item{win_dif}{Difference in total wins (Red minus Blue).}
#'   \item{loss_dif}{Difference in total losses (Red minus Blue).}
#'   \item{total_round_dif}{Difference in total rounds fought (Red minus Blue).}
#'   \item{total_title_bout_dif}{Difference in total title bouts fought (Red minus Blue).}
#'   \item{ko_dif}{Difference in career KO/TKO wins (Red minus Blue).}
#'   \item{sub_dif}{Difference in career submission wins (Red minus Blue).}
#'   \item{height_dif}{Difference in height in centimeters (Red minus Blue).}
#'   \item{reach_dif}{Difference in reach in centimeters (Red minus Blue).}
#'   \item{age_dif}{Difference in age (Red minus Blue).}
#'   \item{sig_str_dif}{Difference in average significant strikes landed (Red minus Blue).}
#'   \item{avg_sub_att_dif}{Difference in average submission attempts (Red minus Blue).}
#'   \item{avg_td_dif}{Difference in average takedowns landed (Red minus Blue).}
#'   \item{empty_arena}{Numeric/Logical indicator for fights that took place without an audience.}
#'
#'   \item{R_match_weightclass_rank, B_match_weightclass_rank}{Fighter's rank in the division of the current bout.}
#'   \item{better_rank}{Indicates which corner held the superior ranking ("Red", "Blue", or "neither").}
#'   \item{R_<division>_rank, B_<division>_rank}{Specific divisional ranks for Red and Blue fighters across all weight classes (e.g., Heavyweight, Bantamweight, Women's Flyweight, Pound-for-Pound).}
#'
#'   \item{finish}{The method of the bout's conclusion (e.g., KO/TKO, SUB, U-DEC).}
#'   \item{finish_details}{Specifics on the finishing sequence (e.g., "Punches", "Rear Naked Choke").}
#'   \item{finish_round}{The round in which the bout ended.}
#'   \item{finish_round_time}{The exact time on the clock when the fight was stopped (MM:SS).}
#'   \item{total_fight_time_secs}{The cumulative duration of the bout in seconds.}
#'
#'   \item{r_dec_odds, b_dec_odds}{Prop bet odds for the fighter to win by Decision.}
#'   \item{r_sub_odds, b_sub_odds}{Prop bet odds for the fighter to win by Submission.}
#'   \item{r_ko_odds, b_ko_odds}{Prop bet odds for the fighter to win by KO/TKO.}
#' }
#' @source Matthew Dabbert, Kaggle \url{https://www.kaggle.com/datasets/mdabbert/ultimate-ufc-dataset/data}
#' @name ultimate_ufc_dataset
#' @docType data
NULL


#' UFC Rankings Dataset
#'
#' A historical dataset containing Ultimate Fighting Championship (UFC) rankings
#' over time. It tracks the divisional and pound-for-pound rankings of fighters
#' across various dates, providing a longitudinal view of a fighter's status
#' within the promotion.
#'
#' @format A data frame (tibble) with 99,847 rows and 4 variables:
#' \describe{
#'   \item{date}{The date the ranking was published (YYYY-MM-DD).}
#'   \item{weightclass}{The weight division or ranking category (e.g., "Pound-for-Pound", "Heavyweight", "Women's Strawweight").}
#'   \item{fighter}{The name of the fighter.}
#'   \item{rank}{The fighter's numerical rank in the specified weight class on that date. A rank of `0` typically designates the reigning Champion.}
#' }
#' @source Octagon API \url{https://api.octagon-api.com/rankings}
#' @name ufc_rankings_dataset
#' @docType data
NULL

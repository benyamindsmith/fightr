<img align="right" height="300"  alt="fightr_logo" src="https://github.com/user-attachments/assets/3675ac06-b941-47bc-b927-2b980000e0ff" />

# fightr
**fightr** is a statistical framework for analyzing combat sports data in R. 

Because the landscape of mixed martial arts changes weekly, shipping static data inside a package quickly becomes obsolete. `fightr` solves this by utilizing a CRAN-compliant local caching architecture to dynamically fetch the latest UFC data from GitHub. 

Beyond data retrieval, `fightr` provides a robust, mathematically rigorous modeling suite to estimate latent fighter ability parameters and predict bout outcomes using advanced maximum likelihood estimation techniques and network subgraphing.

## Installation

```r
# install.packages("devtools")
devtools::install_github("benyamindsmith/fightr")
```

## 1. Dynamic Data Retrieval

`fightr` provides seamless access to three core, dynamically updated datasets (`ufc_athletes`, `ufc_fights`, and `ufcstats_data`). The package uses a polite caching mechanism—if the data is missing or stale (older than 7 days), it automatically downloads the latest versions in the background.

```r
library(fightr)

# Loads from local cache, fetching updates automatically if needed
athletes <- get_ufc_data("ufc_athletes")
fights   <- get_ufc_data("ufc_fights")

# Force a manual refresh of all datasets
update_all_ufc_data()
```

## 2. Statistical Modeling & Prop Probabilities

The core analytical engine of `fightr` is `model_fight_outcome()`. This function predicts the probability of a win and the specific method of victory (KO/TKO, Submission, Decision) for any hypothetical or scheduled matchup. 

It supports three distinct statistical frameworks:

* **Multinomial Logistic Regression (`"multinomial"`):** A baseline model utilizing 19 distinct fighter differentials (age, reach, striking/grappling metrics) to predict specific fight outcomes.
* **Bradley-Terry Network Model (`"bradley-terry"`):** A pairwise comparison model utilizing a Logit link function. It builds a historical degree-2 subgraph around the selected fighters to estimate unobserved ability parameters ($\lambda$), weighted by their individual historical prop rates.
* **Thurstone-Mosteller Network Model (`"thurstone-mosteller"`):** A variation of the pairwise comparison framework utilizing a Probit link function, assuming normally distributed latent performance levels.

### Example Usage

```r
library(fightr)

# Predict an outcome using the Bradley-Terry subgraph model
matchup_model <- model_fight_outcome(
  fighter1 = "Islam Makhachev",
  fighter2 = "Alexander Volkanovski",
  method_type = "bradley-terry"
)

# The function returns an S3 object containing the fitted model and predictions
print(matchup_model$method_probs)
```

### Integrated Visualization

By default, `model_fight_outcome()` generates a clean `ggplot2` visualization of the prop odds spread. The plot object is stored within the returned list for easy extraction and further customization.

```r
# Extract and display the probability chart
matchup_model$plot
```

## Roadmap

Future releases of `fightr` will continue to expand the analytical toolset:

* **Network Visualizations:** Integrated functions to map and plot the degree-2 subgraphs utilized by the Bradley-Terry and Thurstone-Mosteller models.
* **Live Odds Integration:** Fetching and comparing implied probabilities from live sportsbook data against the model's theoretical estimates to identify positive expected value (+EV) lines.
* **Model Diagnostics:** Exportable summary tables for parameter standard errors, AIC/BIC metrics, and goodness-of-fit tests for the underlying `multinom` and `BTm` objects.

## CRAN Compliance Note

`fightr` strictly adheres to CRAN repository policies regarding user data and file system modification. The package will **never** silently download data or write to your file system upon running `library(fightr)`. All downloads require an explicit function call by the user, and all cached data is stored safely in `tools::R_user_dir("fightr", which = "cache")`.

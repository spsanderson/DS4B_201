
# Data Preperation --------------------------------------------------------
# Machine Readable ----

# Lib Load ----------------------------------------------------------------

if(!require(pacman)) {install.packages("pacman")}
pacman::p_load(
    "recipes"
    , "readxl"
    , "tidyverse"
    , "tidyquant"
)


# Data Load ---------------------------------------------------------------

path_train <- "00_Data/telco_train.xlsx"
path_test <- "00_Data/telco_test.xlsx"
path_data_definitions <- "00_Data/telco_data_definitions.xlsx"

train_raw_tbl <- read_excel(path_train, sheet = 1)
test_raw_tbl <- read_excel(path_test, sheet = 1)
definitions_raw_tbl <- read_excel(path_data_definitions, sheet = 1, col_names = FALSE) %>%
    set_names("X__1","X__2")


# Processing Pipeline -----------------------------------------------------

source("00_Scripts/data_processing_pipeline.R")
train_readable_tbl <- process_hr_data_readable(train_raw_tbl, definitions_raw_tbl)
test_readable_tbl <- process_hr_data_readable(test_raw_tbl, definitions_raw_tbl)


# Plot Faceted Histogram Function -----------------------------------------
.data <- train_raw_tbl
plot_hist_facet <- function(.data, .bins = 10, .ncol = 5, .fct_reorder = FALSE,
                            .fct_rev = FALSE, .fill = palette_light()[[3]],
                            .color = "white", .scale = "free") {
    
    data_factored <- .data %>%
        mutate_if(is.character, as.factor) %>%
        mutate_if(is.factor, as.numeric) %>%
        gather(key = key, value = value, factor_key = TRUE)
    
    if (.fct_reorder) {
        data_factored <- data_factored %>%
            mutate(key = as.character(key) %>% as.factor())
    }
    
    if (.fct_reorder) {
        data_factored <- data_factored %>%
            mutate(key = fct_rev(key))
    }
    
    g <- data_factored %>%
        ggplot(aes(x = value, group = key)) +
        geom_histogram(bins = .bins, fill = .fill, color = .color) +
        facet_wrap(~ key, ncol = .ncol, scale = .scale) +
        theme_tq()
    
    return(g)
    
}

train_raw_tbl %>%
    select(Attrition, everything()) %>%
    plot_hist_facet(.bins = 10, .ncol = 5)


# Data Preprocess with recipies -------------------------------------------

# Plan
# 1. Impute / Zero Var Features ----
rec_obj <- recipe(Attrition ~ ., data = train_readable_tbl) %>%
    step_zv(all_predictors())

# 2. Transformations ----

!skewed_feature_names %in% c("JobLevel","StockOptionLevel")

skewed_feature_names <- train_readable_tbl %>%
    select_if(is.numeric) %>%
    map_df(skewness) %>%
    pivot_longer(cols = everything(), names_to = "key") %>%
    arrange(desc(value)) %>%
    filter(value >= 0.8) %>%
    filter(!key %in% c("JobLevel","StockOptionLevel")) %>%
    pull(key) %>%
    as.character()

train_readable_tbl %>%
    select(skewed_feature_names) %>%
    plot_hist_facet()

factor_names <- c("JobLevel","StockOptionLevel")

rec_obj <- recipe(Attrition ~ ., data = train_readable_tbl) %>%
    step_zv(all_predictors()) %>%
    step_YeoJohnson(skewed_feature_names) %>%
    step_mutate_at(factor_names, fn = as.factor)

# 3. Discretize ----
# 4. Normalization / Centr & Scaling ----
# 5. Dummy Var ----
# 6. Interaction Variable / Engineered Features ----
# 7. Multivariate Transformation ----
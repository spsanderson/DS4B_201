# Challenge # 5 Solution Code ----
# Note that this is an extension of the Chapter 8 Code
# and all Chapter 8 code must be run first!

# Part 1: Find optimal threshold ----

avg_overtime_pct   <- 0.10 
net_revenue_per_employee <- 250000
stock_option_cost <- 5000

# Part 1: Solution ----

data <- test_tbl
h2o_model <- automl_leader

threshold <- 0
tnr <- 0
fpr <- 1
fnr <- 0
tpr <- 1

avg_overtime_pct <- 0.10
net_revenue_per_employee <- 250000
stock_option_cost <- 5000

calculate_savings_by_threshold_3 <- function(data, h2o_model, threshold = 0,
                                             tnr = 0, fpr = 1, fnr = 0, tpr = 1,
                                             avg_overtime_pct = 0.10,
                                             net_revenue_per_employee = 250000,
                                             stock_option_cost = 5000) {
    
    data_0_tbl <- as_tibble(data)
    
    
    # 4. Expected Value 
    
    # 4.1 Calculating Expected Value With OT 
    
    pred_0_tbl <- h2o_model %>%
        h2o.predict(newdata = as.h2o(data_0_tbl)) %>%
        as_tibble() %>%
        bind_cols(
            # Changed in _3 ----
            data_0_tbl %>%
                select(EmployeeNumber, MonthlyIncome, OverTime, StockOptionLevel)
        )
    
    ev_0_tbl <- pred_0_tbl %>%
        mutate(
            attrition_cost = calculate_attrition_cost(
                n = 1,
                salary = MonthlyIncome * 12,
                # Changed in _2 ----
                net_revenue_per_employee = net_revenue_per_employee) 
        ) %>%
        mutate(
            cost_of_policy_change = 0
        ) %>%
        mutate(
            expected_attrition_cost = 
                Yes * (attrition_cost + cost_of_policy_change) +
                No *  (cost_of_policy_change)
        )
    
    
    total_ev_0_tbl <- ev_0_tbl %>%
        summarise(
            total_expected_attrition_cost_0 = sum(expected_attrition_cost)
        )
    
    # 4.2 Calculating Expected Value With Targeted OT & Stock Option Policy
    
    data_1_tbl <- data_0_tbl %>%
        add_column(Yes = pred_0_tbl$Yes) %>%
        mutate(
            OverTime = case_when(
                Yes >= threshold ~ factor("No", levels = levels(data_0_tbl$OverTime)),
                TRUE ~ OverTime
            )
        ) %>%
        # Changed in _3 ----
    mutate(
        StockOptionLevel = case_when(
            Yes >= threshold & StockOptionLevel == 0 
            ~ factor("1", levels = levels(data_0_tbl$StockOptionLevel)),
            TRUE ~ StockOptionLevel
        )
    ) %>%
        select(-Yes) 
    
    pred_1_tbl <- h2o_model %>%
        h2o.predict(newdata = as.h2o(data_1_tbl)) %>%
        as_tibble() %>%
        # Changed in _3 ----
    bind_cols(
        data_0_tbl %>%
            select(EmployeeNumber, MonthlyIncome, OverTime, StockOptionLevel),
        data_1_tbl %>%
            select(OverTime, StockOptionLevel)
    ) %>%
        rename(
            OverTime_0 = `OverTime...6`,
            OverTime_1 = `OverTime...8`,
            # Changed in _3 ----
            StockOptionLevel_0 = `StockOptionLevel...7`,
            StockOptionLevel_1 = `StockOptionLevel...9`
        )
    
    
    avg_overtime_pct <- avg_overtime_pct # Changed in _2 ----
    stock_option_cost <- stock_option_cost # Changed in _3 ----
    
    ev_1_tbl <- pred_1_tbl %>%
        mutate(
            attrition_cost = calculate_attrition_cost(
                n = 1,
                salary = MonthlyIncome * 12,
                # Changed in _2 ----
                net_revenue_per_employee = net_revenue_per_employee)
        ) %>%
        # Changed in _3 ----
    # cost_OT
    mutate(
        cost_OT = case_when(
            OverTime_1 == "No" & OverTime_0 == "Yes" 
            ~ avg_overtime_pct * MonthlyIncome * 12,
            TRUE ~ 0
        )
    ) %>%
        # cost Stock Options
        mutate(
            cost_SO = case_when(
                StockOptionLevel_1 == "1" & StockOptionLevel_0 == "0"
                ~ stock_option_cost,
                TRUE ~ 0
            )
        ) %>%
        mutate(cost_of_policy_change = cost_OT + cost_SO) %>%
        mutate(
            cb_tn = cost_of_policy_change,
            cb_fp = cost_of_policy_change,
            cb_fn = attrition_cost + cost_of_policy_change,
            cb_tp = attrition_cost + cost_of_policy_change,
            expected_attrition_cost = Yes * (tpr*cb_tp + fnr*cb_fn) + 
                No * (tnr*cb_tn + fpr*cb_fp)
        ) 
    
    
    total_ev_1_tbl <- ev_1_tbl %>%
        summarise(
            total_expected_attrition_cost_1 = sum(expected_attrition_cost)
        )
    
    
    # 4.3 Savings Calculation
    
    savings_tbl <- bind_cols(
        total_ev_0_tbl,
        total_ev_1_tbl
    ) %>%
        mutate(
            savings = total_expected_attrition_cost_0 - total_expected_attrition_cost_1,
            pct_savings = savings / total_expected_attrition_cost_0
        )
    
    return(savings_tbl$savings)
    
}

max_f1_tbl <- rates_by_threshold_tbl %>%
    select(threshold, f1, tnr:tpr) %>%
    filter(f1 == max(f1))

max_f1_savings <- calculate_savings_by_threshold_3(
    test_tbl, automl_leader,
    threshold = max_f1_tbl$threshold,
    tnr = max_f1_tbl$tnr,
    fpr = max_f1_tbl$fpr,
    fnr = max_f1_tbl$fnr,
    tpr = max_f1_tbl$tpr,
    avg_overtime_pct = 0.10,
    net_revenue_per_employee = 250000,
    stock_option_cost = 5000
)

# Optimization

smpl <- seq(1, 220, length.out = 20) %>% round(digits = 0)

calculate_savings_by_threshold_3_preloded <- 
    partial(calculate_savings_by_threshold_3, 
            data = test_tbl, 
            h2o_model = automl_leader,
            avg_overtime_pct = 0.10,
            net_revenue_per_employee = 250000,
            stock_option_cost = 5000)

rates_by_threshold_optimized_tbl_3 <- rates_by_threshold_tbl %>%
    select(threshold, tnr:tpr) %>%
    slice(smpl) %>%
    mutate(
        savings = pmap_dbl(
            .l = list(
                threshold = threshold,
                tnr = tnr,
                fnr = fnr,
                fpr = fpr,
                tpr = tpr
            ),
            .f = calculate_savings_by_threshold_3_preloded
        )
    )

rates_by_threshold_optimized_tbl_3

rates_by_threshold_optimized_tbl_3 %>%
    filter(savings == max(savings))


rates_by_threshold_optimized_tbl_3 %>%
    ggplot(aes(threshold, savings)) +
    
    # Vlines
    geom_vline(xintercept = max_f1_tbl$threshold, 
               color = palette_light()[[5]], size = 2) +
    geom_vline(aes(xintercept = threshold), 
               color = palette_light()[[3]], size = 2,
               data = rates_by_threshold_optimized_tbl_3 %>%
                   filter(savings == max(savings))
    ) +
    
    # Points
    geom_line(color = palette_light()[[1]]) +
    geom_point(color = palette_light()[[1]]) +
    
    # F1 Max
    annotate(geom = "label", label = scales::dollar(max_f1_savings),
             x = max_f1_tbl$threshold, y = max_f1_savings, vjust = -1,
             color = palette_light()[[1]]) + 
    
    # Optimal Point
    geom_point(shape = 21, size = 5, color = palette_light()[[3]],
               data = rates_by_threshold_optimized_tbl_3 %>%
                   filter(savings == max(savings))) +
    geom_label(aes(label = scales::dollar(savings)), 
               vjust = -2, color = palette_light()[[3]],
               data = rates_by_threshold_optimized_tbl_3 %>%
                   filter(savings == max(savings))) +
    
    # No OT Policy
    geom_point(shape = 21, size = 5, color = palette_light()[[2]],
               data = rates_by_threshold_optimized_tbl_3 %>%
                   filter(threshold == min(threshold))) +
    geom_label(aes(label = scales::dollar(savings)), 
               vjust = -1, color = palette_light()[[2]],
               data = rates_by_threshold_optimized_tbl_3 %>%
                   filter(threshold == min(threshold))) +
    
    # Do Nothing Policy
    geom_point(shape = 21, size = 5, color = palette_light()[[2]],
               data = rates_by_threshold_optimized_tbl_3 %>%
                   filter(threshold == max(threshold))) +
    geom_label(aes(label = scales::dollar(round(savings, 0))), 
               vjust = -1, color = palette_light()[[2]],
               data = rates_by_threshold_optimized_tbl_3 %>%
                   filter(threshold == max(threshold))) +
    
    # Aesthestics
    theme_tq() +
    expand_limits(x = c(-.1, 1.1), y = 12e5) +
    scale_x_continuous(labels = scales::percent, 
                       breaks = seq(0, 1, by = 0.2)) +
    scale_y_continuous(labels = scales::dollar) +
    labs(
        title = "Optimization Results: Expected Savings Maximized At 18.9%",
        x = "Threshold (%)", y = "Savings"
    )

# Part 2: Perform sensitivity analysis at optimal threshold ----

net_revenue_per_employee <- 250000
avg_overtime_pct <- seq(0.05, 0.3, by = 0.05)
stock_option_cost <- seq(5000, 25000, by = 5000)


# ============================================================
# HR Attrition Analysis | IBM HR Analytics Dataset
# Author: Gabrielle Magalhaes
# Description: Exploratory analysis of employee attrition patterns
# Run this on Google Colab, one cell at a time
# ============================================================


# ============================================================
# CELL 1 — Imports and data loading
# ============================================================

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# visual style
sns.set_theme(style="whitegrid", palette="muted")
plt.rcParams["figure.figsize"] = (10, 5)

# load dataset
df = pd.read_csv("data/WA_Fn-UseC_-HR-Employee-Attrition.csv")

print("Shape:", df.shape)
df.head()


# ============================================================
# CELL 2 — Basic info and data types
# ============================================================

df.info()


# ============================================================
# CELL 3 — Check for nulls
# ============================================================

print("Null values per column:")
print(df.isnull().sum())


# ============================================================
# CELL 4 — Convert Attrition to numeric (Yes=1, No=0)
# ============================================================

df["Attrition_num"] = df["Attrition"].map({"Yes": 1, "No": 0})
df["OverTime_num"] = df["OverTime"].map({"Yes": 1, "No": 0})

print("Attrition distribution:")
print(df["Attrition"].value_counts())
print(f"\nOverall attrition rate: {df['Attrition_num'].mean():.1%}")


# ============================================================
# CELL 5 — Attrition rate by Department
# ============================================================

dept_attrition = (
    df.groupby("Department")["Attrition_num"]
    .agg(["mean", "sum", "count"])
    .rename(columns={"mean": "attrition_rate", "sum": "left", "count": "total"})
    .sort_values("attrition_rate", ascending=False)
)

dept_attrition["attrition_rate_pct"] = (dept_attrition["attrition_rate"] * 100).round(1)
print(dept_attrition)

# plot
fig, ax = plt.subplots()
ax.bar(dept_attrition.index, dept_attrition["attrition_rate_pct"], color=["#e05c5c", "#e09a5c", "#5c8ae0"])
ax.set_title("Attrition Rate by Department (%)", fontsize=13, fontweight="bold")
ax.set_ylabel("Attrition Rate (%)")
ax.set_xlabel("Department")
for i, v in enumerate(dept_attrition["attrition_rate_pct"]):
    ax.text(i, v + 0.3, f"{v}%", ha="center", fontsize=11)
plt.tight_layout()
plt.savefig("attrition_by_department.png", dpi=150)
plt.show()


# ============================================================
# CELL 6 — Monthly income: who left vs who stayed
# ============================================================

fig, ax = plt.subplots()
df.boxplot(column="MonthlyIncome", by="Attrition", ax=ax,
           boxprops=dict(color="#5c8ae0"),
           medianprops=dict(color="#e05c5c", linewidth=2))
ax.set_title("Monthly Income Distribution: Left vs Stayed", fontsize=13, fontweight="bold")
ax.set_xlabel("Attrition")
ax.set_ylabel("Monthly Income (USD)")
plt.suptitle("")  # remove default boxplot title
plt.tight_layout()
plt.savefig("income_vs_attrition.png", dpi=150)
plt.show()

# print averages
print("Average income by attrition status:")
print(df.groupby("Attrition")["MonthlyIncome"].mean().round(2))


# ============================================================
# CELL 7 — Attrition rate by tenure cohort
# ============================================================

def tenure_cohort(years):
    if years == 0:
        return "0 - First year"
    elif years <= 2:
        return "1-2 years"
    elif years <= 5:
        return "3-5 years"
    elif years <= 10:
        return "6-10 years"
    else:
        return "10+ years"

df["tenure_cohort"] = df["YearsAtCompany"].apply(tenure_cohort)

cohort_order = ["0 - First year", "1-2 years", "3-5 years", "6-10 years", "10+ years"]

cohort_attrition = (
    df.groupby("tenure_cohort")["Attrition_num"]
    .agg(["mean", "sum", "count"])
    .rename(columns={"mean": "attrition_rate", "sum": "left", "count": "total"})
    .reindex(cohort_order)
)
cohort_attrition["attrition_rate_pct"] = (cohort_attrition["attrition_rate"] * 100).round(1)
print(cohort_attrition)

# plot
fig, ax = plt.subplots()
colors = ["#e05c5c", "#e07a5c", "#e09a5c", "#a0b87a", "#5cb87a"]
ax.bar(cohort_attrition.index, cohort_attrition["attrition_rate_pct"], color=colors)
ax.set_title("Attrition Rate by Tenure Cohort (%)", fontsize=13, fontweight="bold")
ax.set_ylabel("Attrition Rate (%)")
ax.set_xlabel("Years at Company")
for i, v in enumerate(cohort_attrition["attrition_rate_pct"]):
    ax.text(i, v + 0.3, f"{v}%", ha="center", fontsize=11)
plt.tight_layout()
plt.savefig("attrition_by_tenure.png", dpi=150)
plt.show()


# ============================================================
# CELL 8 — Overtime vs attrition
# ============================================================

overtime_attrition = (
    df.groupby("OverTime")["Attrition_num"]
    .agg(["mean", "count"])
    .rename(columns={"mean": "attrition_rate", "count": "total"})
)
overtime_attrition["attrition_rate_pct"] = (overtime_attrition["attrition_rate"] * 100).round(1)
print(overtime_attrition)

# plot
fig, ax = plt.subplots(figsize=(6, 5))
ax.bar(["No Overtime", "Overtime"], overtime_attrition["attrition_rate_pct"],
       color=["#5c8ae0", "#e05c5c"])
ax.set_title("Attrition Rate: Overtime vs No Overtime (%)", fontsize=13, fontweight="bold")
ax.set_ylabel("Attrition Rate (%)")
for i, v in enumerate(overtime_attrition["attrition_rate_pct"]):
    ax.text(i, v + 0.3, f"{v}%", ha="center", fontsize=12)
plt.tight_layout()
plt.savefig("attrition_overtime.png", dpi=150)
plt.show()


# ============================================================
# CELL 9 — Risk scoring: flag employees at risk
# ============================================================

# calculate department median income
dept_median = df.groupby("Department")["MonthlyIncome"].median().rename("dept_median_income")
df = df.merge(dept_median, on="Department")

# apply risk flags (active employees only)
active = df[df["Attrition"] == "No"].copy()

active["flag_overtime"]       = (active["OverTime"] == "Yes").astype(int)
active["flag_below_median"]   = (active["MonthlyIncome"] < active["dept_median_income"]).astype(int)
active["flag_low_satisfaction"] = (active["JobSatisfaction"] <= 2).astype(int)
active["total_risk_flags"]    = (
    active["flag_overtime"] +
    active["flag_below_median"] +
    active["flag_low_satisfaction"]
)

high_risk = active[active["total_risk_flags"] >= 2][
    ["EmployeeNumber", "Department", "JobRole", "MonthlyIncome",
     "dept_median_income", "OverTime", "JobSatisfaction",
     "YearsAtCompany", "total_risk_flags"]
].sort_values("total_risk_flags", ascending=False)

print(f"Active employees flagged as high risk: {len(high_risk)}")
print(f"Total active employees: {len(active)}")
print(f"High risk rate: {len(high_risk)/len(active):.1%}")
print()
high_risk.head(20)


# ============================================================
# CELL 10 — Summary of findings
# ============================================================

print("=" * 55)
print("KEY FINDINGS — HR Attrition Analysis")
print("=" * 55)

overall_rate = df["Attrition_num"].mean()
print(f"\nOverall attrition rate: {overall_rate:.1%}")

top_dept = dept_attrition["attrition_rate_pct"].idxmax()
top_dept_rate = dept_attrition["attrition_rate_pct"].max()
print(f"Highest attrition department: {top_dept} ({top_dept_rate}%)")

first_year_rate = cohort_attrition.loc["0 - First year", "attrition_rate_pct"]
print(f"First year attrition rate: {first_year_rate}%")

ot_yes = overtime_attrition.loc["Yes", "attrition_rate_pct"]
ot_no  = overtime_attrition.loc["No",  "attrition_rate_pct"]
print(f"Attrition with overtime: {ot_yes}% vs without: {ot_no}%")

avg_left  = df[df["Attrition"]=="Yes"]["MonthlyIncome"].mean()
avg_stayed = df[df["Attrition"]=="No"]["MonthlyIncome"].mean()
print(f"Avg income - left: ${avg_left:,.0f} | stayed: ${avg_stayed:,.0f}")

print(f"\nActive employees at high risk: {len(high_risk)} ({len(high_risk)/len(active):.1%})")
print("=" * 55)

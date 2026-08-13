# ESOF-5011-Group5-Recipe-Based-Weekly-Meal-Planning-and-Grocery-Optimization
Recipe-Based Weekly Meal Planning and Grocery Optimization with Chinese-Cuisine Preference, Dynamic Prices, and Controlled Randomness

This project is a recipe-based weekly meal planning and grocery optimization system developed in MATLAB.

Main Function

The main function of the project is:

runMealPlanner.m

Run this file to start the meal-planning program. It loads the required data, solves the CVX relaxation, recovers a feasible weekly menu, checks the constraints, and generates the final meal plan and grocery results.

For performance comparison and scalability testing, we also use:

runPerformanceAnalysis.m

This script compares CVX + Argmax, CVX + Repair, and the exact MILP solution using intlinprog.

Data Files

All Excel data files are stored in the:

data/

folder.

The data include:

Recipes
Ingredients
RecipeIngredients
Prices
Settings

If new recipes, ingredients, or monthly prices need to be added, please update the corresponding Excel tables in the data folder.

For a new recipe, information such as recipe name, cuisine type, meal compatibility, nutrition, preparation time, preference score, and ingredient amounts should be added.

For a new month, the package prices can be added or updated in the price data.

How to Run
Keep the MATLAB code and the data folder in the correct project directory.
Make sure CVX is installed and available in MATLAB.
Open MATLAB and set the current folder to the project folder.
Run:

runMealPlanner

The program will generate a 7-day meal plan with 21 meals, grocery package information, cost, leftovers, and feasibility results.

The current model also requires 8 to 9 of the 14 lunches and dinners to be Chinese meals, while breakfast remains flexible.


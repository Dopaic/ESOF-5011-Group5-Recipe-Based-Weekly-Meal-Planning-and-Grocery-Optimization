function data = loadMealData(dataFile, selectedMonth)
% Source tables

recipes = readtable(dataFile, 'Sheet', 'Recipes', 'TextType', 'string');
ingredients = readtable(dataFile, 'Sheet', 'Ingredients', 'TextType', 'string');
prices = readtable(dataFile, 'Sheet', 'Prices', 'TextType', 'string');
recipeIngredients = readtable(dataFile, 'Sheet', 'RecipeIngredients', 'TextType', 'string');

% Numeric conversion
recipeNumericColumns = ["AllowedBreakfast", "AllowedLunch", "AllowedDinner", ...
    "Calories_kcal", "Protein_g", "Carbs_g", "Fat_g", "Sugar_g", ...
    "Fiber_g", "Sodium_mg", "PrepTime_min", "Preference_1to5", "MaxWeeklyUses"];
for columnName = recipeNumericColumns
    recipes.(columnName) = toNumeric(recipes.(columnName));
end

ingredients.PackageSize_g = toNumeric(ingredients.PackageSize_g);
ingredients.DefaultPrice_CAD = toNumeric(ingredients.DefaultPrice_CAD);
prices.PricePerPackage_CAD = toNumeric(prices.PricePerPackage_CAD);
recipeIngredients.Amount_g = toNumeric(recipeIngredients.Amount_g);

% Monthly prices
numberOfIngredients = height(ingredients);
currentPrice = zeros(numberOfIngredients, 1);
priceSource = strings(numberOfIngredients, 1);

for ingredientIndex = 1:numberOfIngredients
    ingredientID = ingredients.IngredientID(ingredientIndex);
    matchingRows = prices.IngredientID == ingredientID & prices.Month == selectedMonth;

    if any(matchingRows)
        firstMatch = find(matchingRows, 1, 'first');
        currentPrice(ingredientIndex) = prices.PricePerPackage_CAD(firstMatch);
        priceSource(ingredientIndex) = prices.Source(firstMatch);
    else
        currentPrice(ingredientIndex) = ingredients.DefaultPrice_CAD(ingredientIndex);
        priceSource(ingredientIndex) = "Default price used because the selected month was missing";
    end
end

% I x R grams
numberOfRecipes = height(recipes);
recipeIngredientMatrix = zeros(numberOfIngredients, numberOfRecipes);

for rowIndex = 1:height(recipeIngredients)
    recipeIndex = find(recipes.RecipeID == recipeIngredients.RecipeID(rowIndex), 1);
    ingredientIndex = find(ingredients.IngredientID == recipeIngredients.IngredientID(rowIndex), 1);

    if ~isempty(recipeIndex) && ~isempty(ingredientIndex)
        recipeIngredientMatrix(ingredientIndex, recipeIndex) = ...
            recipeIngredientMatrix(ingredientIndex, recipeIndex) + recipeIngredients.Amount_g(rowIndex);
    end
end

% Fixed nutrient order
nutrientNames = ["Calories_kcal", "Protein_g", "Carbs_g", "Fat_g", ...
    "Sugar_g", "Fiber_g", "Sodium_mg"];
nutrientMatrix = [recipes.Calories_kcal'; recipes.Protein_g'; recipes.Carbs_g'; ...
    recipes.Fat_g'; recipes.Sugar_g'; recipes.Fiber_g'; recipes.Sodium_mg'];

% Recipe cost estimate
unitCostPerGram = currentPrice ./ ingredients.PackageSize_g;
approximateRecipeCost = recipeIngredientMatrix' * unitCostPerGram;

% Data structure
data.DataFile = dataFile;
data.SelectedMonth = string(selectedMonth);
data.Recipes = recipes;
data.Ingredients = ingredients;
data.Prices = prices;
data.RecipeIngredients = recipeIngredients;
data.CurrentPrice = currentPrice;
data.PriceSource = priceSource;
data.RecipeIngredientMatrix = recipeIngredientMatrix;
data.NutrientNames = nutrientNames;
data.NutrientMatrix = nutrientMatrix;
data.ApproximateRecipeCost = approximateRecipeCost;
data.NumberOfRecipes = numberOfRecipes;
data.NumberOfIngredients = numberOfIngredients;
data.NumberOfDays = 7;
data.NumberOfMeals = 3;
data.DayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
data.MealNames = ["Breakfast", "Lunch", "Dinner"];
end

function numericValue = toNumeric(inputValue)
% Numeric conversion

if isnumeric(inputValue)
    numericValue = double(inputValue);
else
    numericValue = str2double(string(inputValue));
end
end

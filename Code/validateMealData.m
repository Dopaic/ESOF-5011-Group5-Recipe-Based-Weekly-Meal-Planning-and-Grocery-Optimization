function validateMealData(data, config)
% Input validation

recipes = data.Recipes;
ingredients = data.Ingredients;

% Unique identifiers
if numel(unique(recipes.RecipeID)) ~= height(recipes)
    error('RecipeID values must be unique.');
end
if numel(unique(ingredients.IngredientID)) ~= height(ingredients)
    error('IngredientID values must be unique.');
end

% Recipe availability
if sum(recipes.AllowedBreakfast == 1) < 4
    error('At least four breakfast recipes are required.');
end
if sum(recipes.AllowedLunch == 1 | recipes.AllowedDinner == 1) < 14
    error('At least fourteen lunch/dinner recipes are recommended.');
end

% Cuisine feasibility
chineseLunchDinner = recipes.Cuisine == "Chinese" & ...
    (recipes.AllowedLunch == 1 | recipes.AllowedDinner == 1);
if sum(chineseLunchDinner) < config.ChineseLunchDinnerMax
    error('Not enough Chinese lunch/dinner recipes to satisfy the cuisine constraint.');
end

% Ingredient links
recipeUsage = sum(data.RecipeIngredientMatrix, 1);
missingRecipes = find(recipeUsage <= 0);
if ~isempty(missingRecipes)
    names = strjoin(recipes.RecipeName(missingRecipes), ', ');
    error('These recipes have no ingredients: %s', names);
end

% Numeric ranges
if any(ingredients.PackageSize_g <= 0) || any(data.CurrentPrice <= 0)
    error('Package sizes and prices must be greater than zero.');
end
nutritionColumns = [recipes.Calories_kcal, recipes.Protein_g, recipes.Carbs_g, ...
    recipes.Fat_g, recipes.Sugar_g, recipes.Fiber_g, recipes.Sodium_mg];
if any(~isfinite(nutritionColumns), 'all') || any(nutritionColumns < 0, 'all') || ...
        any(recipes.Calories_kcal <= 0) || any(recipes.Preference_1to5 < 1) || ...
        any(recipes.Preference_1to5 > 5)
    error(['Nutrition values must be finite and nonnegative, calories must be positive, ' ...
        'and preference scores must be between 1 and 5.']);
end

% Setting bounds
if config.WeeklyBudget_CAD <= 0
    error('Weekly budget must be greater than zero.');
end
if config.ChineseLunchDinnerMin > config.ChineseLunchDinnerMax
    error('ChineseLunchDinnerMin cannot exceed ChineseLunchDinnerMax.');
end
if config.CarbsMin_g > config.CarbsMax_g
    error('CarbsMin_g cannot exceed CarbsMax_g.');
end
end

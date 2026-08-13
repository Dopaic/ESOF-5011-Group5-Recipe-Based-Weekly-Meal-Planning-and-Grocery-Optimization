function addRecipeInteractive(dataFile)
% Recipe input

recipes = readtable(dataFile, 'Sheet', 'Recipes', 'TextType', 'string');
ingredients = readtable(dataFile, 'Sheet', 'Ingredients', 'TextType', 'string');
prices = readtable(dataFile, 'Sheet', 'Prices', 'TextType', 'string');
recipeIngredients = readtable(dataFile, 'Sheet', 'RecipeIngredients', 'TextType', 'string');
settings = loadSettings(dataFile);

fprintf('\n--- Add a New Recipe ---\n');

% Recipe ID
recipeID = nextIdentifier(recipes.RecipeID, 'R');
recipeName = askText('Recipe name: ');
cuisine = askText('Cuisine (Chinese, Western, Japanese, Korean, etc.): ');
mealCodes = upper(askText('Allowed meals (use B, L, D; example LD): '));
allowedBreakfast = double(contains(mealCodes, 'B'));
allowedLunch = double(contains(mealCodes, 'L'));
allowedDinner = double(contains(mealCodes, 'D'));

if allowedBreakfast + allowedLunch + allowedDinner == 0
    error('At least one meal type must be allowed.');
end

% Serving nutrition
calories = askNumber('Calories per serving (kcal): ', 1, inf);
protein = askNumber('Protein per serving (g): ', 0, inf);
carbs = askNumber('Carbohydrates per serving (g): ', 0, inf);
fat = askNumber('Fat per serving (g): ', 0, inf);
sugar = askNumber('Sugar per serving (g): ', 0, inf);
fiber = askNumber('Fibre per serving (g): ', 0, inf);
sodium = askNumber('Sodium per serving (mg): ', 0, inf);
prepTime = askNumber('Preparation time (minutes): ', 0, inf);
preference = askNumber('Preference score (1 to 5): ', 1, 5);
mainProtein = askText('Main protein (Chicken, Beef, Pork, Fish, Egg, Tofu, or None): ');
cookingMethod = askText('Cooking method (Stir-fried, Boiled, Baked, etc.): ');
maxWeeklyUses = round(askNumber('Maximum weekly uses [recommended 1 or 2]: ', 1, 7));

% Deferred save
newRecipe = table(string(recipeID), string(recipeName), string(cuisine), ...
    allowedBreakfast, allowedLunch, allowedDinner, calories, protein, carbs, ...
    fat, sugar, fiber, sodium, prepTime, preference, string(mainProtein), ...
    string(cookingMethod), maxWeeklyUses, ...
    'VariableNames', recipes.Properties.VariableNames);

newRecipeIngredientRows = recipeIngredients([],:);
numberOfIngredientsAdded = 0;

fprintf('\nEnter ingredients used by one serving. Leave the name blank when finished.\n');
while true
    ingredientName = strtrim(input('Ingredient name: ', 's'));
    if isempty(ingredientName)
        break;
    end

    matchingIngredient = find(strcmpi(ingredients.IngredientName, ingredientName), 1);

    if isempty(matchingIngredient)
        fprintf('This ingredient is not in the database. A new ingredient will be created.\n');
        ingredientID = nextIdentifier(ingredients.IngredientID, 'I');
        packageSize = askNumber('Package size (g or mL-equivalent): ', 1, inf);
        category = askText('Ingredient category: ');
        defaultPrice = askNumber(sprintf('Package price for %s (CAD): ', settings.SelectedMonth), 0.01, inf);

        newIngredient = table(string(ingredientID), string(ingredientName), ...
            packageSize, string(category), defaultPrice, ...
            'VariableNames', ingredients.Properties.VariableNames);
        ingredients = [ingredients; newIngredient]; %#ok<AGROW>

        newPrice = table(string(settings.SelectedMonth), string(ingredientID), ...
            defaultPrice, "User-entered price", ...
            'VariableNames', prices.Properties.VariableNames);
        prices = [prices; newPrice]; %#ok<AGROW>
    else
        ingredientID = ingredients.IngredientID(matchingIngredient);
    end

    amountUsed = askNumber('Amount used in one serving (g): ', 0.1, inf);
    newLink = table(string(recipeID), string(ingredientID), amountUsed, ...
        'VariableNames', recipeIngredients.Properties.VariableNames);
    newRecipeIngredientRows = [newRecipeIngredientRows; newLink]; %#ok<AGROW>
    numberOfIngredientsAdded = numberOfIngredientsAdded + 1;
end

if numberOfIngredientsAdded == 0
    error('The recipe was not saved because no ingredients were entered.');
end

% Append records
recipes = [recipes; newRecipe];
recipeIngredients = [recipeIngredients; newRecipeIngredientRows];

% Preserve worksheets
writetable(recipes, dataFile, 'Sheet', 'Recipes', 'WriteMode', 'overwritesheet');
writetable(ingredients, dataFile, 'Sheet', 'Ingredients', 'WriteMode', 'overwritesheet');
writetable(prices, dataFile, 'Sheet', 'Prices', 'WriteMode', 'overwritesheet');
writetable(recipeIngredients, dataFile, 'Sheet', 'RecipeIngredients', 'WriteMode', 'overwritesheet');

fprintf('\nRecipe added successfully.\n');
fprintf('  Recipe ID: %s\n', recipeID);
fprintf('  Recipe name: %s\n', recipeName);
fprintf('  Ingredients entered: %d\n', numberOfIngredientsAdded);
end

function value = askText(promptText)
% Nonempty input

while true
    value = strtrim(input(promptText, 's'));
    if ~isempty(value)
        return;
    end
    fprintf('A value is required.\n');
end
end

function value = askNumber(promptText, minimumValue, maximumValue)
% Range validation

while true
    rawValue = strtrim(input(promptText, 's'));
    value = str2double(rawValue);
    if isfinite(value) && value >= minimumValue && value <= maximumValue
        return;
    end
    fprintf('Enter a number between %.2f and %.2f.\n', minimumValue, maximumValue);
end
end

function identifier = nextIdentifier(existingIdentifiers, prefix)
% Three-digit ID

largestNumber = 0;
for index = 1:numel(existingIdentifiers)
    token = regexp(char(existingIdentifiers(index)), '\d+', 'match', 'once');
    if ~isempty(token)
        largestNumber = max(largestNumber, str2double(token));
    end
end
identifier = sprintf('%s%03d', prefix, largestNumber + 1);
end

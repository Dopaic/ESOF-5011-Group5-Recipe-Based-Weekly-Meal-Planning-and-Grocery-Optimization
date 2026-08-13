function listRecipes(dataFile)
% Recipe overview

recipes = readtable(dataFile, 'Sheet', 'Recipes', 'TextType', 'string');
summary = recipes(:, {'RecipeID', 'RecipeName', 'Cuisine', ...
    'AllowedBreakfast', 'AllowedLunch', 'AllowedDinner', ...
    'Calories_kcal', 'Protein_g', 'Fat_g', 'Sugar_g', ...
    'PrepTime_min', 'Preference_1to5'});

disp(summary);
fprintf('Total recipes: %d\n', height(recipes));
end

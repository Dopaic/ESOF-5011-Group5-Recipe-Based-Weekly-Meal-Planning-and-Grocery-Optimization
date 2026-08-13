function [isValid, violations] = validateCandidate(candidate, data, config, displayResult)
if nargin < 4
    displayResult = true;
end

isValid = true;
violations = strings(0, 1);
tol = 1e-5;

if isempty(candidate) || ~isfield(candidate, 'Z') || isempty(candidate.Z)
    isValid = false;
    violations(end+1) = "Empty candidate provided.";
    return;
end

Z = candidate.Z;
q = candidate.Packages;
D = data.NumberOfDays;
M = data.NumberOfMeals;
allowedByMeal = [data.Recipes.AllowedBreakfast, data.Recipes.AllowedLunch, data.Recipes.AllowedDinner];

if any(abs(Z(:) - round(Z(:))) > tol) || any(Z(:) < -tol) || any(Z(:) > 1 + tol)
    isValid = false;
    violations(end+1) = "Recipe assignment variables are not binary.";
end

if any(~isfinite(q)) || any(q < -tol) || any(abs(q - round(q)) > tol)
    isValid = false;
    violations(end+1) = "Package quantities are not valid nonnegative integers.";
end

for d = 1:D
    for m = 1:M
        if abs(sum(Z(:, d, m)) - 1) > tol
            isValid = false;
            violations(end+1) = sprintf("Day %d, Meal %d does not have exactly 1 recipe.", d, m);
        end
        selectedRecipe = find(Z(:, d, m) > 0.5);
        if numel(selectedRecipe) == 1 && allowedByMeal(selectedRecipe, m) < 0.5
            isValid = false;
            violations(end+1) = sprintf("Recipe %s is not allowed for Day %d, Meal %d.", ...
                data.Recipes.RecipeName(selectedRecipe), d, m);
        end
    end
end

usedGrams = data.RecipeIngredientMatrix * sum(sum(Z, 2), 3);
boughtGrams = data.Ingredients.PackageSize_g .* q;
waste = boughtGrams - usedGrams;
if any(waste < -tol)
    isValid = false;
    shortageIdx = find(waste < -tol, 1);
    violations(end+1) = sprintf("Ingredient shortage: %s (Short by %.1f g).", ...
        data.Ingredients.IngredientName(shortageIdx), -waste(shortageIdx));
end

actualCost = data.CurrentPrice' * q;
if actualCost > config.WeeklyBudget_CAD + tol
    isValid = false;
    violations(end+1) = sprintf("Budget exceeded: %.2f > %.2f", actualCost, config.WeeklyBudget_CAD);
end

dailyNutrients = zeros(size(data.NutrientMatrix, 1), D);
for d = 1:D
    dailyNutrients(:, d) = data.NutrientMatrix * sum(Z(:, d, :), 3);
end
bounds = [
    config.CaloriesMin, config.CaloriesMax;
    config.ProteinMin_g, inf;
    config.CarbsMin_g, config.CarbsMax_g;
    config.FatMin_g, config.FatMax_g;
    -inf, config.SugarMax_g;
    config.FiberMin_g, inf;
    -inf, config.SodiumMax_mg
];
metricNames = ["Calories", "Protein", "Carbs", "Fat", "Sugar", "Fiber", "Sodium"];

for d = 1:D
    for i = 1:length(metricNames)
        val = dailyNutrients(i, d);
        if val < bounds(i, 1) - tol
            isValid = false;
            violations(end+1) = sprintf("Day %d %s too low: %.1f < %.1f", d, metricNames(i), val, bounds(i, 1));
        end
        if val > bounds(i, 2) + tol
            isValid = false;
            violations(end+1) = sprintf("Day %d %s too high: %.1f > %.1f", d, metricNames(i), val, bounds(i, 2));
        end
    end
end

chineseIdx = find(data.Recipes.Cuisine == "Chinese");
chineseCount = sum(Z(chineseIdx, :, 2:3), 'all');
if chineseCount < config.ChineseLunchDinnerMin - tol || chineseCount > config.ChineseLunchDinnerMax + tol
    isValid = false;
    violations(end+1) = sprintf("Chinese meal count %d out of bounds [%d, %d].", ...
        round(chineseCount), config.ChineseLunchDinnerMin, config.ChineseLunchDinnerMax);
end

zTotal = sum(sum(Z, 2), 3);
if any(zTotal > data.Recipes.MaxWeeklyUses + tol)
    isValid = false;
    violatingRecipe = find(zTotal > data.Recipes.MaxWeeklyUses + tol, 1);
    violations(end+1) = sprintf("Recipe %s used too many times.", data.Recipes.RecipeName(violatingRecipe));
end

for d = 1:(D - 1)
    for m = 1:M
        if any(Z(:, d, m) + Z(:, d+1, m) > 1 + tol)
            isValid = false;
            violations(end+1) = sprintf("Recipe repeated on consecutive days (%d and %d) at meal %d.", d, d+1, m);
        end
    end
end

for d = 1:D
    dailyTime = data.Recipes.PrepTime_min' * sum(Z(:, d, :), 3);
    dayOfWeek = mod(d, 7);
    if dayOfWeek == 6 || dayOfWeek == 0
        if dailyTime > config.WeekendPrepLimit_min + tol
            isValid = false;
            violations(end+1) = sprintf("Day %d (Weekend) prep time exceeded: %.1f > %.1f", d, dailyTime, config.WeekendPrepLimit_min);
        end
    else
        if dailyTime > config.WeekdayPrepLimit_min + tol
            isValid = false;
            violations(end+1) = sprintf("Day %d (Weekday) prep time exceeded: %.1f > %.1f", d, dailyTime, config.WeekdayPrepLimit_min);
        end
    end
end

proteinTypes = unique(data.Recipes.MainProtein);
proteinTypes(proteinTypes == "None") = [];
for p = 1:numel(proteinTypes)
    matchingRecipes = find(data.Recipes.MainProtein == proteinTypes(p));
    pCount = sum(Z(matchingRecipes, :, 2:3), 'all');
    if pCount > config.MaxSameProteinLunchDinner + tol
        isValid = false;
        violations(end+1) = sprintf("Protein %s used too many times in lunch/dinner: %d > %d", ...
            proteinTypes(p), round(pCount), config.MaxSameProteinLunchDinner);
    end
end

if displayResult
    if isValid
        fprintf('  [OK] Independent validation passed. All constraints are strictly met.\n');
    else
        fprintf('  [!] Validation FAILED. Violations found:\n');
        for v = 1:length(violations)
            fprintf('      - %s\n', violations(v));
        end
    end
end
end

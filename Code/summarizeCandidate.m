function candidate = summarizeCandidate(solution, expressions, data, config, applyRepair)
if nargin < 5
    applyRepair = true;
end

R = size(solution.z, 1);
D = size(solution.z, 2);
M = size(solution.z, 3);
candidate.Z = zeros(R, D, M);

for dayIndex = 1:D
    for mealIndex = 1:M
        allowedRecipeIndex = findAllowedRecipes(data, mealIndex);
        [~, order] = sort(solution.z(allowedRecipeIndex, dayIndex, mealIndex), 'descend');
        selectedRecipe = allowedRecipeIndex(order(1));
        candidate.Z(selectedRecipe, dayIndex, mealIndex) = 1;
    end
end

repairIterations = 0;
if applyRepair
    [candidate.Z, repairIterations] = repairMenu(candidate.Z, solution.z, data, config);
    candidate.Z = improveMenu(candidate.Z, solution.z, data, config);
end

[violationCount, violationScore, metrics] = evaluateMenu(candidate.Z, data, config);

candidate.Packages = metrics.Packages;
candidate.Waste_g = metrics.Waste_g;
candidate.IngredientUse_g = metrics.IngredientUse_g;
candidate.TotalCost = metrics.TotalCost;
candidate.DailyNutrients = metrics.DailyNutrients;
candidate.ChineseLunchDinnerCount = metrics.ChineseLunchDinnerCount;
candidate.DailyPreparationTime = metrics.DailyPreparationTime;
candidate.TotalWaste_g = metrics.TotalWaste_g;
candidate.AveragePreference = metrics.AveragePreference;
candidate.UniqueRecipes = metrics.UniqueRecipes;
candidate.QualityValue = metrics.QualityValue;
candidate.RelaxedQualityValue = full(expressions.Quality);
candidate.RecoveryGapToRelaxed = (candidate.QualityValue - candidate.RelaxedQualityValue) / max(abs(candidate.RelaxedQualityValue), 1e-9);
candidate.ViolationCount = violationCount;
candidate.ViolationScore = violationScore;
candidate.RepairIterations = repairIterations;
candidate.RepairApplied = applyRepair;
candidate.IsFeasible = violationCount == 0;
end

function [Z, iterations] = repairMenu(Z, relaxedZ, data, config)
maxRepairIterations = 40;
iterations = 0;

for iter = 1:maxRepairIterations
    [currentCount, currentScore, currentMetrics] = evaluateMenu(Z, data, config);
    if currentCount == 0
        break;
    end

    currentTie = currentMetrics.QualityValue + 0.02 * confidencePenalty(Z, relaxedZ);
    bestZ = Z;
    bestCount = currentCount;
    bestScore = currentScore;
    bestTie = currentTie;
    improved = false;

    for dayIndex = 1:data.NumberOfDays
        for mealIndex = 1:data.NumberOfMeals
            currentRecipe = find(Z(:, dayIndex, mealIndex) > 0.5, 1);
            allowedRecipeIndex = findAllowedRecipes(data, mealIndex);
            [~, order] = sort(relaxedZ(allowedRecipeIndex, dayIndex, mealIndex), 'descend');
            allowedRecipeIndex = allowedRecipeIndex(order);

            for recipeIndex = reshape(allowedRecipeIndex, 1, [])
                if recipeIndex == currentRecipe
                    continue;
                end

                testZ = Z;
                testZ(currentRecipe, dayIndex, mealIndex) = 0;
                testZ(recipeIndex, dayIndex, mealIndex) = 1;
                [testCount, testScore, testMetrics] = evaluateMenu(testZ, data, config);
                testTie = testMetrics.QualityValue + 0.02 * confidencePenalty(testZ, relaxedZ);

                if isBetterState(testCount, testScore, testTie, bestCount, bestScore, bestTie)
                    bestZ = testZ;
                    bestCount = testCount;
                    bestScore = testScore;
                    bestTie = testTie;
                    improved = true;
                end
            end
        end
    end

    if ~improved || ~isBetterState(bestCount, bestScore, bestTie, currentCount, currentScore, currentTie)
        break;
    end

    Z = bestZ;
    iterations = iter;
end
end

function Z = improveMenu(Z, relaxedZ, data, config)
[violationCount, ~, currentMetrics] = evaluateMenu(Z, data, config);
if violationCount ~= 0
    return;
end

maxPasses = 4;
for passIndex = 1:maxPasses
    bestZ = Z;
    bestObjective = currentMetrics.QualityValue;
    bestConfidence = confidencePenalty(Z, relaxedZ);
    improved = false;

    for dayIndex = 1:data.NumberOfDays
        for mealIndex = 1:data.NumberOfMeals
            currentRecipe = find(Z(:, dayIndex, mealIndex) > 0.5, 1);
            allowedRecipeIndex = findAllowedRecipes(data, mealIndex);

            for recipeIndex = reshape(allowedRecipeIndex, 1, [])
                if recipeIndex == currentRecipe
                    continue;
                end

                testZ = Z;
                testZ(currentRecipe, dayIndex, mealIndex) = 0;
                testZ(recipeIndex, dayIndex, mealIndex) = 1;
                [testCount, ~, testMetrics] = evaluateMenu(testZ, data, config);
                if testCount ~= 0
                    continue;
                end

                testConfidence = confidencePenalty(testZ, relaxedZ);
                if testMetrics.QualityValue < bestObjective - 1e-8 || ...
                        (abs(testMetrics.QualityValue - bestObjective) <= 1e-8 && testConfidence < bestConfidence - 1e-8)
                    bestZ = testZ;
                    bestObjective = testMetrics.QualityValue;
                    bestConfidence = testConfidence;
                    improved = true;
                end
            end
        end
    end

    if ~improved
        break;
    end

    Z = bestZ;
    [~, ~, currentMetrics] = evaluateMenu(Z, data, config);
end
end

function better = isBetterState(countA, scoreA, tieA, countB, scoreB, tieB)
tol = 1e-10;
if countA < countB
    better = true;
elseif countA > countB
    better = false;
elseif scoreA < scoreB - tol
    better = true;
elseif scoreA > scoreB + tol
    better = false;
else
    better = tieA < tieB - tol;
end
end

function [violationCount, violationScore, metrics] = evaluateMenu(Z, data, config)
metrics = calculateMetrics(Z, data);
violationCount = 0;
violationScore = 0;
tol = 1e-8;

allowedByMeal = [data.Recipes.AllowedBreakfast, data.Recipes.AllowedLunch, data.Recipes.AllowedDinner];
for dayIndex = 1:data.NumberOfDays
    for mealIndex = 1:data.NumberOfMeals
        mealSum = sum(Z(:, dayIndex, mealIndex));
        if abs(mealSum - 1) > tol
            violationCount = violationCount + 1;
            violationScore = violationScore + abs(mealSum - 1);
        end
        selectedRecipe = find(Z(:, dayIndex, mealIndex) > 0.5);
        if numel(selectedRecipe) ~= 1 || (numel(selectedRecipe) == 1 && allowedByMeal(selectedRecipe, mealIndex) < 0.5)
            violationCount = violationCount + 1;
            violationScore = violationScore + 1;
        end
    end
end

if metrics.TotalCost > config.WeeklyBudget_CAD + tol
    violationCount = violationCount + 1;
    violationScore = violationScore + (metrics.TotalCost - config.WeeklyBudget_CAD) / max(1, config.WeeklyBudget_CAD);
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

for dayIndex = 1:data.NumberOfDays
    for metricIndex = 1:size(bounds, 1)
        value = metrics.DailyNutrients(metricIndex, dayIndex);
        lowerBound = bounds(metricIndex, 1);
        upperBound = bounds(metricIndex, 2);
        if isfinite(lowerBound) && value < lowerBound - tol
            violationCount = violationCount + 1;
            violationScore = violationScore + (lowerBound - value) / max(1, abs(lowerBound));
        end
        if isfinite(upperBound) && value > upperBound + tol
            violationCount = violationCount + 1;
            violationScore = violationScore + (value - upperBound) / max(1, abs(upperBound));
        end
    end
end

if metrics.ChineseLunchDinnerCount < config.ChineseLunchDinnerMin - tol
    violationCount = violationCount + 1;
    violationScore = violationScore + (config.ChineseLunchDinnerMin - metrics.ChineseLunchDinnerCount) / max(1, config.ChineseLunchDinnerMin);
elseif metrics.ChineseLunchDinnerCount > config.ChineseLunchDinnerMax + tol
    violationCount = violationCount + 1;
    violationScore = violationScore + (metrics.ChineseLunchDinnerCount - config.ChineseLunchDinnerMax) / max(1, config.ChineseLunchDinnerMax);
end

zTotal = sum(sum(Z, 2), 3);
for recipeIndex = 1:data.NumberOfRecipes
    maxUses = data.Recipes.MaxWeeklyUses(recipeIndex);
    if zTotal(recipeIndex) > maxUses + tol
        violationCount = violationCount + 1;
        violationScore = violationScore + (zTotal(recipeIndex) - maxUses) / max(1, maxUses);
    end
end

for dayIndex = 1:(data.NumberOfDays - 1)
    for mealIndex = 1:data.NumberOfMeals
        if any(Z(:, dayIndex, mealIndex) + Z(:, dayIndex + 1, mealIndex) > 1 + tol)
            violationCount = violationCount + 1;
            violationScore = violationScore + 1;
        end
    end
end

for dayIndex = 1:data.NumberOfDays
    if mod(dayIndex, 7) == 6 || mod(dayIndex, 7) == 0
        limit = config.WeekendPrepLimit_min;
    else
        limit = config.WeekdayPrepLimit_min;
    end
    if metrics.DailyPreparationTime(dayIndex) > limit + tol
        violationCount = violationCount + 1;
        violationScore = violationScore + (metrics.DailyPreparationTime(dayIndex) - limit) / max(1, limit);
    end
end

proteinTypes = unique(data.Recipes.MainProtein);
proteinTypes(proteinTypes == "None") = [];
for proteinIndex = 1:numel(proteinTypes)
    matchingRecipes = find(data.Recipes.MainProtein == proteinTypes(proteinIndex));
    proteinCount = sum(Z(matchingRecipes, :, 2:3), 'all');
    if proteinCount > config.MaxSameProteinLunchDinner + tol
        violationCount = violationCount + 1;
        violationScore = violationScore + (proteinCount - config.MaxSameProteinLunchDinner) / max(1, config.MaxSameProteinLunchDinner);
    end
end
end

function metrics = calculateMetrics(Z, data)
recipeCounts = sum(sum(Z, 2), 3);
ingredientUse = data.RecipeIngredientMatrix * recipeCounts;
packages = ceil(max(ingredientUse, 0) ./ data.Ingredients.PackageSize_g - 1e-10);
packages = max(packages, 0);
waste = max(data.Ingredients.PackageSize_g .* packages - ingredientUse, 0);

dailyNutrients = zeros(size(data.NutrientMatrix, 1), data.NumberOfDays);
dailyPreparationTime = zeros(1, data.NumberOfDays);
for dayIndex = 1:data.NumberOfDays
    dayRecipeCount = sum(Z(:, dayIndex, :), 3);
    dailyNutrients(:, dayIndex) = data.NutrientMatrix * dayRecipeCount;
    dailyPreparationTime(dayIndex) = data.Recipes.PrepTime_min' * dayRecipeCount;
end

chineseRecipeIndex = find(data.Recipes.Cuisine == "Chinese");
chineseCount = sum(Z(chineseRecipeIndex, :, 2:3), 'all');
totalCost = data.CurrentPrice' * packages;
wastePenalty = sum(waste ./ data.Ingredients.PackageSize_g);
preferencePenalty = sum(((5 - data.Recipes.Preference_1to5) / 4) .* recipeCounts);
qualityValue = totalCost + 0.6 * wastePenalty + 0.03 * sum(dailyPreparationTime) + 0.55 * preferencePenalty;

metrics.Packages = packages;
metrics.Waste_g = waste;
metrics.IngredientUse_g = ingredientUse;
metrics.TotalCost = totalCost;
metrics.DailyNutrients = dailyNutrients;
metrics.ChineseLunchDinnerCount = chineseCount;
metrics.DailyPreparationTime = dailyPreparationTime;
metrics.TotalWaste_g = sum(waste);
metrics.AveragePreference = sum(recipeCounts .* data.Recipes.Preference_1to5) / max(sum(recipeCounts), 1);
metrics.UniqueRecipes = sum(recipeCounts > 0);
metrics.QualityValue = qualityValue;
end

function penalty = confidencePenalty(Z, relaxedZ)
penalty = 0;
for dayIndex = 1:size(Z, 2)
    for mealIndex = 1:size(Z, 3)
        selectedRecipe = find(Z(:, dayIndex, mealIndex) > 0.5, 1);
        if ~isempty(selectedRecipe)
            penalty = penalty + (1 - relaxedZ(selectedRecipe, dayIndex, mealIndex));
        end
    end
end
end

function recipeIndex = findAllowedRecipes(data, mealIndex)
if mealIndex == 1
    recipeIndex = find(data.Recipes.AllowedBreakfast > 0.5);
elseif mealIndex == 2
    recipeIndex = find(data.Recipes.AllowedLunch > 0.5);
else
    recipeIndex = find(data.Recipes.AllowedDinner > 0.5);
end
end

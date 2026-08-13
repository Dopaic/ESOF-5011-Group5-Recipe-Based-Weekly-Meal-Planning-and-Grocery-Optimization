function runPerformanceAnalysis()
clc;
fprintf('============================================================\n');
fprintf(' PERFORMANCE ANALYSIS: CVX Recovery vs. Exact MILP\n');
fprintf('============================================================\n');

projectRoot = fileparts(mfilename('fullpath'));
dataFile = fullfile(projectRoot, 'data', 'meal_planner_data.xlsx');
config = loadSettings(dataFile);
data = loadMealData(dataFile, config.SelectedMonth);

WEIGHT_WASTE = 0.6;
WEIGHT_PREP  = 0.03;
WEIGHT_PREF  = 0.55;

fprintf('Weights: Waste=%.2f, Prep=%.2f, Pref=%.2f\n', ...
    WEIGHT_WASTE, WEIGHT_PREP, WEIGHT_PREF);

fprintf('\n--- Solving Exact MILP ---\n');
milpResult = solveExactMILP(data, config, WEIGHT_WASTE, WEIGHT_PREP, WEIGHT_PREF);
if milpResult.exitflag > 0
    [milpResult.isValid, ~] = validateCandidate(milpResult, data, config, false);
else
    milpResult.isValid = false;
end

fprintf('\n--- Solving CVX Relaxation and Recovery Variants ---\n');
[naiveResult, proposedResult] = solveCVXVariants(data, config, WEIGHT_WASTE, WEIGHT_PREP, WEIGHT_PREF);
if ~isempty(naiveResult.Z)
    [naiveResult.isValid, ~] = validateCandidate(naiveResult, data, config, false);
else
    naiveResult.isValid = false;
end
if ~isempty(proposedResult.Z)
    [proposedResult.isValid, ~] = validateCandidate(proposedResult, data, config, false);
else
    proposedResult.isValid = false;
end

integralityGap = calculateGap(milpResult.actualObjective, proposedResult.relaxedQuality, true);
naiveGap = calculateGap(milpResult.actualObjective, naiveResult.actualObjective, false);
proposedGap = calculateGap(milpResult.actualObjective, proposedResult.actualObjective, false);

fprintf('\n============================================================\n');
fprintf(' RESULTS COMPARISON\n');
fprintf('============================================================\n');
fprintf('%-24s %14s %14s %14s\n', 'Metric', 'CVX+Argmax', 'CVX+Repair', 'Exact MILP');
fprintf('%-24s %14.2f %14.2f %14.2f\n', 'Total Cost (CAD)', naiveResult.actualCost, proposedResult.actualCost, milpResult.actualCost);
fprintf('%-24s %14.2f %14.2f %14.2f\n', 'Waste Penalty', naiveResult.actualWastePen, proposedResult.actualWastePen, milpResult.actualWastePen);
fprintf('%-24s %14.2f %14.2f %14.2f\n', 'Prep Penalty', naiveResult.actualPrepPen, proposedResult.actualPrepPen, milpResult.actualPrepPen);
fprintf('%-24s %14.2f %14.2f %14.2f\n', 'Preference Penalty', naiveResult.actualPrefPen, proposedResult.actualPrefPen, milpResult.actualPrefPen);
fprintf('%-24s %14.2f %14.2f %14.2f\n', 'Overall Objective', naiveResult.actualObjective, proposedResult.actualObjective, milpResult.actualObjective);
fprintf('%-24s %14.2f %14.2f %14.2f\n', 'Total Time (s)', naiveResult.solverTime, proposedResult.solverTime, milpResult.solverTime);
fprintf('%-24s %14s %14s %14s\n', 'Feasible', logicalText(naiveResult.isValid), logicalText(proposedResult.isValid), logicalText(milpResult.isValid));
fprintf('%-24s %14.2f %14.2f %14.2f\n', 'Gap to Exact (%%)', naiveGap, proposedGap, 0);
fprintf('%-24s %14s %14.2f %14s\n', 'Integrality Gap (%%)', '---', integralityGap, '---');
fprintf('%-24s %14.2f %14.2f %14s\n', 'CVX Relaxed Obj', naiveResult.relaxedQuality, proposedResult.relaxedQuality, '---');

fprintf('\nIndependent validation:\n');
fprintf('  CVX+Argmax: %s\n', logicalText(naiveResult.isValid));
fprintf('  CVX+Repair: %s\n', logicalText(proposedResult.isValid));
fprintf('  Exact MILP: %s\n', logicalText(milpResult.isValid));

plotComparison(naiveResult, proposedResult, milpResult, data);

fprintf('\n--- Scalability Analysis (Recipe count vs. Time) ---\n');
scalabilityAnalysis(data, config, WEIGHT_WASTE, WEIGHT_PREP, WEIGHT_PREF);

fprintf('\nPerformance analysis completed.\n');
end

% Exact MILP
function result = solveExactMILP(data, config, wWaste, wPrep, wPref)
R = data.NumberOfRecipes;
I = data.NumberOfIngredients;
D = data.NumberOfDays;
M = data.NumberOfMeals;
recipes = data.Recipes;

allowedByMeal = [recipes.AllowedBreakfast, recipes.AllowedLunch, recipes.AllowedDinner];
upperBoundZ = repmat(reshape(allowedByMeal, [R, 1, M]), [1, D, 1]);

z = optimvar('z', R, D, M, 'Type', 'integer', 'LowerBound', 0, 'UpperBound', upperBoundZ);
q = optimvar('q', I, 1, 'Type', 'integer', 'LowerBound', 0, 'UpperBound', 10 * D);
waste = optimvar('waste', I, 1, 'LowerBound', 0);

prob = optimproblem('ObjectiveSense', 'minimize');

% One recipe per meal
prob.Constraints.oneRecipe = sum(z, 1) == 1;

% Inventory balance
ingredientUse = optimexpr(I, 1);
for d = 1:D
    for m = 1:M
        ingredientUse = ingredientUse + data.RecipeIngredientMatrix * z(:, d, m);
    end
end
prob.Constraints.inventory = data.Ingredients.PackageSize_g .* q == ingredientUse + waste;

% Objective
costExpr = data.CurrentPrice' * q;
wasteExpr = sum(waste ./ data.Ingredients.PackageSize_g);
dailyPrep = optimexpr(D, 1);
for d = 1:D
    dailyPrep(d) = recipes.PrepTime_min' * sum(z(:, d, :), 3);
end
prepTotal = sum(dailyPrep);
normalizedPref = (5 - recipes.Preference_1to5) / 4;
zTotal = sum(sum(z, 2), 3);
prefPenalty = normalizedPref' * zTotal;
prob.Objective = costExpr + wWaste * wasteExpr + wPrep * prepTotal + wPref * prefPenalty;

% Budget limit
prob.Constraints.budget = costExpr <= config.WeeklyBudget_CAD;

% Cuisine count
chineseIdx = find(recipes.Cuisine == "Chinese");
chineseCount = sum(z(chineseIdx, :, 2:3), 'all');
prob.Constraints.chineseMin = chineseCount >= config.ChineseLunchDinnerMin;
prob.Constraints.chineseMax = chineseCount <= config.ChineseLunchDinnerMax;

% Nutrient bounds
dailyNutrients = optimexpr(size(data.NutrientMatrix, 1), D);
for d = 1:D
    dailyNutrients(:, d) = data.NutrientMatrix * sum(z(:, d, :), 3);
end
prob.Constraints.calMin  = dailyNutrients(1, :) >= config.CaloriesMin;
prob.Constraints.calMax  = dailyNutrients(1, :) <= config.CaloriesMax;
prob.Constraints.protMin = dailyNutrients(2, :) >= config.ProteinMin_g;
prob.Constraints.carbMin = dailyNutrients(3, :) >= config.CarbsMin_g;
prob.Constraints.carbMax = dailyNutrients(3, :) <= config.CarbsMax_g;
prob.Constraints.fatMin  = dailyNutrients(4, :) >= config.FatMin_g;
prob.Constraints.fatMax  = dailyNutrients(4, :) <= config.FatMax_g;
prob.Constraints.sugarMax = dailyNutrients(5, :) <= config.SugarMax_g;
prob.Constraints.fiberMin = dailyNutrients(6, :) >= config.FiberMin_g;
prob.Constraints.sodiumMax = dailyNutrients(7, :) <= config.SodiumMax_mg;

% Weekly usage limits
prob.Constraints.maxUses = zTotal <= recipes.MaxWeeklyUses;

% No adjacent repeats
for d = 1:(D - 1)
    for m = 1:M
        prob.Constraints.(['noRepeat_d' num2str(d) '_m' num2str(m)]) = ...
            z(:, d, m) + z(:, d+1, m) <= 1;
    end
end

% Preparation limits
for d = 1:D
    dayOfWeek = mod(d, 7);
    if dayOfWeek == 6 || dayOfWeek == 0
        prob.Constraints.(['prepLimit_d' num2str(d)]) = dailyPrep(d) <= config.WeekendPrepLimit_min;
    else
        prob.Constraints.(['prepLimit_d' num2str(d)]) = dailyPrep(d) <= config.WeekdayPrepLimit_min;
    end
end

% Protein diversity
proteinTypes = unique(recipes.MainProtein);
proteinTypes(proteinTypes == "None") = [];
for p = 1:numel(proteinTypes)
    matchingRecipes = find(recipes.MainProtein == proteinTypes(p));
    countExpr = sum(sum(sum(z(matchingRecipes, :, 2:3))));
    safeFieldName = matlab.lang.makeValidName(['protein_' char(proteinTypes(p))]);
    prob.Constraints.(safeFieldName) = countExpr <= config.MaxSameProteinLunchDinner;end

% Solve MILP
options = optimoptions('intlinprog', 'Display', 'off');
tic;
[sol, ~, exitflag, output] = solve(prob, 'Options', options);
solverTime = toc;

result.exitflag = exitflag;
result.solverTime = solverTime;

if exitflag > 0
    result.Z = round(sol.z);
    result.Packages = round(sol.q);
    result.waste = sol.waste;
    result.actualCost = evaluate(costExpr, sol);
    result.actualWastePen = wWaste * evaluate(wasteExpr, sol);
    result.actualPrepPen = wPrep * evaluate(prepTotal, sol);
    result.actualPrefPen = wPref * evaluate(prefPenalty, sol);
    result.actualObjective = result.actualCost + result.actualWastePen + ...
        result.actualPrepPen + result.actualPrefPen;
    % Daily preparation
    result.DailyPreparationTime = zeros(1, D);
    for d = 1:D
        totalTime = 0;
        for m = 1:M
            idx = find(result.Z(:, d, m) > 0.5, 1);
            if ~isempty(idx)
                totalTime = totalTime + data.Recipes.PrepTime_min(idx);
            end
        end
        result.DailyPreparationTime(d) = totalTime;
    end
else
    result.Z = []; % Empty result
    result.Packages = [];
    result.waste = [];
    result.actualCost = NaN; result.actualWastePen = NaN;
    result.actualPrepPen = NaN; result.actualPrefPen = NaN;
    result.actualObjective = NaN;
    result.DailyPreparationTime = [];
end
end

% CVX recovery
function [naiveResult, proposedResult] = solveCVXVariants(data, config, wWaste, wPrep, wPref)
R = data.NumberOfRecipes;
D = data.NumberOfDays;
M = data.NumberOfMeals;
zeroPenalty = zeros(R, D, M);

tStart = tic;
[solution, expressions, cvx_status] = buildMealProblem(data, config, [], [], zeroPenalty);
cvxSolveTime = toc(tStart);

if isempty(solution)
    naiveResult = emptyCVXResult(cvxSolveTime);
    proposedResult = emptyCVXResult(cvxSolveTime);
    return;
end

tStart = tic;
naiveCandidate = summarizeCandidate(solution, expressions, data, config, false);
naiveRecoveryTime = toc(tStart);

tStart = tic;
proposedCandidate = summarizeCandidate(solution, expressions, data, config, true);
proposedRecoveryTime = toc(tStart);

naiveResult = candidateToResult(naiveCandidate, full(expressions.Quality), cvxSolveTime + naiveRecoveryTime, wWaste, wPrep, wPref, data);
proposedResult = candidateToResult(proposedCandidate, full(expressions.Quality), cvxSolveTime + proposedRecoveryTime, wWaste, wPrep, wPref, data);
naiveResult.cvxStatus = string(cvx_status);
proposedResult.cvxStatus = string(cvx_status);
end

function result = candidateToResult(candidate, relaxedQuality, totalTime, wWaste, wPrep, wPref, data)
realWaste = sum(candidate.Waste_g ./ data.Ingredients.PackageSize_g);
realPrep = sum(candidate.DailyPreparationTime);
zTotal = sum(sum(candidate.Z, 2), 3);
realPref = sum(((5 - data.Recipes.Preference_1to5) / 4) .* zTotal);

result.relaxedQuality = relaxedQuality;
result.actualCost = candidate.TotalCost;
result.actualWastePen = wWaste * realWaste;
result.actualPrepPen = wPrep * realPrep;
result.actualPrefPen = wPref * realPref;
result.actualObjective = result.actualCost + result.actualWastePen + result.actualPrepPen + result.actualPrefPen;
result.solverTime = totalTime;
result.DailyPreparationTime = candidate.DailyPreparationTime;
result.Packages = candidate.Packages;
result.Z = candidate.Z;
result.ViolationCount = candidate.ViolationCount;
result.RepairIterations = candidate.RepairIterations;
end

function result = emptyCVXResult(totalTime)
result.relaxedQuality = NaN;
result.actualObjective = NaN;
result.actualCost = NaN;
result.actualWastePen = NaN;
result.actualPrepPen = NaN;
result.actualPrefPen = NaN;
result.DailyPreparationTime = [];
result.Packages = [];
result.Z = [];
result.ViolationCount = NaN;
result.RepairIterations = NaN;
result.solverTime = totalTime;
result.cvxStatus = "Failed";
end

function gap = calculateGap(exactValue, comparisonValue, isLowerBound)
if ~isfinite(exactValue) || ~isfinite(comparisonValue)
    gap = NaN;
    return;
end
if isLowerBound
    gap = 100 * (exactValue - comparisonValue) / max(abs(exactValue), 1e-9);
else
    gap = 100 * (comparisonValue - exactValue) / max(abs(exactValue), 1e-9);
end
end

function textValue = logicalText(value)
if value
    textValue = 'Yes';
else
    textValue = 'No';
end
end

% Comparison plots
function plotComparison(naive, proposed, milp, data)
figure('Name', 'Recovery Method Performance Comparison', 'Position', [100, 100, 1150, 720], 'Color', 'w');
t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'CVX Recovery Methods vs. Exact MILP', 'FontSize', 16, 'FontWeight', 'bold');
labels = categorical({'CVX+Argmax', 'CVX+Repair', 'Exact MILP'});

nexttile;
categories = {'Cost', 'Waste', 'Prep', 'Preference'};
barData = [
    naive.actualCost, proposed.actualCost, milp.actualCost;
    naive.actualWastePen, proposed.actualWastePen, milp.actualWastePen;
    naive.actualPrepPen, proposed.actualPrepPen, milp.actualPrepPen;
    naive.actualPrefPen, proposed.actualPrefPen, milp.actualPrefPen
];
bar(categorical(categories), barData, 'grouped');
ylabel('Penalty / Cost');
title('Objective Breakdown');
legend('CVX+Argmax', 'CVX+Repair', 'Exact MILP', 'Location', 'best');
grid on;

nexttile;
bar(labels, [naive.actualObjective, proposed.actualObjective, milp.actualObjective]);
ylabel('Total Objective');
title('Overall Objective Value');
grid on;

nexttile;
bar(labels, [naive.solverTime, proposed.solverTime, milp.solverTime]);
ylabel('Time (Seconds)');
title('Total Solve and Recovery Time');
grid on;

nexttile;
bar(labels, double([naive.isValid, proposed.isValid, milp.isValid]));
ylim([0 1.2]);
yticks([0 1]);
yticklabels({'Invalid', 'Feasible'});
title('Independent Feasibility Check');
grid on;
end

% Scalability analysis
function scalabilityAnalysis(data, config, wWaste, wPrep, wPref)
% Scalability settings
recipeCounts = [10, 15, 20, 25, 30]; % Recipe counts
numTrials = 2; % Trial count
maxMILPTime = 60; % MILP timeout

cvxTimes = zeros(length(recipeCounts), numTrials);
milpTimes = zeros(length(recipeCounts), numTrials);
milpFeasible = zeros(length(recipeCounts), numTrials);

allRecipeIdx = 1:data.NumberOfRecipes;
rng(config.RandomSeed);

fprintf('Running scalability tests (recipe counts: %s, trials: %d, MILP time limit: %ds)...\n', ...
    mat2str(recipeCounts), numTrials, maxMILPTime);

for i = 1:length(recipeCounts)
    targetR = recipeCounts(i);
    fprintf('  Testing with %d recipes...\n', targetR);
    for t = 1:numTrials
        fprintf('    Trial %d/%d...', t, numTrials);
        % Recipe sample
        idx = datasample(allRecipeIdx, targetR, 'Replace', false);
        subData = createSubData(data, idx);

        % Cuisine bounds
        cfg = config;
        nChinese = sum(subData.Recipes.Cuisine == "Chinese" & ...
            (subData.Recipes.AllowedLunch | subData.Recipes.AllowedDinner));
        cfg.ChineseLunchDinnerMin = min(config.ChineseLunchDinnerMin, nChinese);
        cfg.ChineseLunchDinnerMax = min(config.ChineseLunchDinnerMax, nChinese);
        cfg.ChineseLunchDinnerMin = min(cfg.ChineseLunchDinnerMin, cfg.ChineseLunchDinnerMax);

        % CVX timing
        try
            tStart = tic;
            zeroPenalty = zeros(targetR, data.NumberOfDays, data.NumberOfMeals);
            [cvxSolution, cvxExpressions, cvxStatus] = buildMealProblem(subData, cfg, [], [], zeroPenalty);
            if ~isempty(cvxSolution)
                summarizeCandidate(cvxSolution, cvxExpressions, subData, cfg, true);
            end
            cvxTimes(i, t) = toc(tStart);
            fprintf(' CVX:%.1fs', cvxTimes(i, t));
        catch
            cvxTimes(i, t) = NaN;
            fprintf(' CVX:FAIL');
        end

        % MILP timing
        try
            milpResult = solveLimitedMILP(subData, cfg, wWaste, wPrep, wPref, maxMILPTime);
            milpTimes(i, t) = milpResult.solverTime;
            milpFeasible(i, t) = milpResult.exitflag > 0;
    
            if milpFeasible(i,t)
                statusStr = 'OK';
            else
                statusStr = 'FAIL';
            end
            fprintf(' MILP:%.1fs(%s)', milpTimes(i, t), statusStr);
        catch
            milpTimes(i, t) = NaN;
            fprintf(' MILP:FAIL');
        end
        fprintf('\n');
    end
end

% Plot results
figure('Name', 'Scalability: Recipe Count vs. Solver Time');
avgCvx = mean(cvxTimes, 2, 'omitnan');
avgMilp = mean(milpTimes, 2, 'omitnan');

yyaxis left;
plot(recipeCounts, avgCvx, 'o-', 'LineWidth', 2, 'Color', [0.2 0.6 0.8]);
ylabel('CVX Time (s)');
hold on;
yyaxis right;
plot(recipeCounts, avgMilp, 's-', 'LineWidth', 2, 'Color', [0.8 0.4 0.2]);
ylabel('MILP Time (s)');
xlabel('Number of Recipes');
title('Average Solver Time vs. Recipe Count');
grid on;
legend('CVX Relaxation', 'Exact MILP', 'Location', 'northwest');

% MILP feasibility
fprintf('MILP feasibility by recipe count:\n');
for i = 1:length(recipeCounts)
    fprintf('  %d recipes: %d/%d feasible\n', recipeCounts(i), ...
        sum(milpFeasible(i,:), 'omitnan'), numTrials);
end
end
function subData = createSubData(data, recipeIdx)
% Subset data
subData = data;
subData.Recipes = data.Recipes(recipeIdx, :);
subData.RecipeIngredientMatrix = data.RecipeIngredientMatrix(:, recipeIdx);
subData.NutrientMatrix = data.NutrientMatrix(:, recipeIdx);
subData.ApproximateRecipeCost = data.ApproximateRecipeCost(recipeIdx);
subData.NumberOfRecipes = length(recipeIdx);
% Shared fields
end

function result = solveLimitedMILP(subData, config, wWaste, wPrep, wPref, timeLimit)
% Timed MILP
R = subData.NumberOfRecipes;
I = subData.NumberOfIngredients;
D = subData.NumberOfDays;
M = subData.NumberOfMeals;
recipes = subData.Recipes;

allowedByMeal = [recipes.AllowedBreakfast, recipes.AllowedLunch, recipes.AllowedDinner];
upperBoundZ = repmat(reshape(allowedByMeal, [R, 1, M]), [1, D, 1]);

z = optimvar('z', R, D, M, 'Type', 'integer', 'LowerBound', 0, 'UpperBound', upperBoundZ);
q = optimvar('q', I, 1, 'Type', 'integer', 'LowerBound', 0, 'UpperBound', 10 * D);
waste = optimvar('waste', I, 1, 'LowerBound', 0);

prob = optimproblem('ObjectiveSense', 'minimize');
prob.Constraints.oneRecipe = sum(z, 1) == 1;

ingredientUse = optimexpr(I, 1);
for d = 1:D
    for m = 1:M
        ingredientUse = ingredientUse + subData.RecipeIngredientMatrix * z(:, d, m);
    end
end
prob.Constraints.inventory = subData.Ingredients.PackageSize_g .* q == ingredientUse + waste;

costExpr = subData.CurrentPrice' * q;
wasteExpr = sum(waste ./ subData.Ingredients.PackageSize_g);
dailyPrep = optimexpr(D, 1);
for d = 1:D
    dailyPrep(d) = recipes.PrepTime_min' * sum(z(:, d, :), 3);
end
prepTotal = sum(dailyPrep);
normalizedPref = (5 - recipes.Preference_1to5) / 4;
zTotal = sum(sum(z, 2), 3);
prefPenalty = normalizedPref' * zTotal;
prob.Objective = costExpr + wWaste * wasteExpr + wPrep * prepTotal + wPref * prefPenalty;

prob.Constraints.budget = costExpr <= config.WeeklyBudget_CAD;
chineseIdx = find(recipes.Cuisine == "Chinese");
if ~isempty(chineseIdx)
    chineseCount = sum(z(chineseIdx, :, 2:3), 'all');
    prob.Constraints.chineseMin = chineseCount >= config.ChineseLunchDinnerMin;
    prob.Constraints.chineseMax = chineseCount <= config.ChineseLunchDinnerMax;
end

dailyNutrients = optimexpr(size(subData.NutrientMatrix, 1), D);
for d = 1:D
    dailyNutrients(:, d) = subData.NutrientMatrix * sum(z(:, d, :), 3);
end
prob.Constraints.calMin  = dailyNutrients(1, :) >= config.CaloriesMin;
prob.Constraints.calMax  = dailyNutrients(1, :) <= config.CaloriesMax;
prob.Constraints.protMin = dailyNutrients(2, :) >= config.ProteinMin_g;
prob.Constraints.carbMin = dailyNutrients(3, :) >= config.CarbsMin_g;
prob.Constraints.carbMax = dailyNutrients(3, :) <= config.CarbsMax_g;
prob.Constraints.fatMin  = dailyNutrients(4, :) >= config.FatMin_g;
prob.Constraints.fatMax  = dailyNutrients(4, :) <= config.FatMax_g;
prob.Constraints.sugarMax = dailyNutrients(5, :) <= config.SugarMax_g;
prob.Constraints.fiberMin = dailyNutrients(6, :) >= config.FiberMin_g;
prob.Constraints.sodiumMax = dailyNutrients(7, :) <= config.SodiumMax_mg;

prob.Constraints.maxUses = zTotal <= recipes.MaxWeeklyUses;
for d = 1:(D - 1)
    for m = 1:M
        prob.Constraints.(['noRepeat' num2str(d) '_' num2str(m)]) = ...
            z(:, d, m) + z(:, d+1, m) <= 1;
    end
end
for d = 1:D
    dayOfWeek = mod(d, 7);
    if dayOfWeek == 6 || dayOfWeek == 0
        prob.Constraints.(['prep' num2str(d)]) = dailyPrep(d) <= config.WeekendPrepLimit_min;
    else
        prob.Constraints.(['prep' num2str(d)]) = dailyPrep(d) <= config.WeekdayPrepLimit_min;
    end
end
proteinTypes = unique(recipes.MainProtein);
proteinTypes(proteinTypes == "None") = [];
for p = 1:numel(proteinTypes)
    matchingRecipes = find(recipes.MainProtein == proteinTypes(p));
    countExpr = sum(sum(sum(z(matchingRecipes, :, 2:3))));
    safeFieldName = matlab.lang.makeValidName(['prot' char(proteinTypes(p))]);
    prob.Constraints.(safeFieldName) = countExpr <= config.MaxSameProteinLunchDinner;
end

options = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', timeLimit);
tic;
[sol, ~, exitflag, ~] = solve(prob, 'Options', options);
result.solverTime = toc;
result.exitflag = exitflag;

if exitflag > 0
    result.Z = round(sol.z);
    result.Packages = round(sol.q);
    result.waste = sol.waste;
    result.actualCost = evaluate(costExpr, sol);
    result.actualWastePen = wWaste * evaluate(wasteExpr, sol);
    result.actualPrepPen = wPrep * evaluate(prepTotal, sol);
    result.actualPrefPen = wPref * evaluate(prefPenalty, sol);
    result.actualObjective = result.actualCost + result.actualWastePen + ...
        result.actualPrepPen + result.actualPrefPen;
else
    result.Z = []; % Empty result
    result.Packages = [];
    result.waste = [];
    result.Packages = [];
    result.actualCost = NaN; result.actualWastePen = NaN;
    result.actualPrepPen = NaN; result.actualPrefPen = NaN;
    result.actualObjective = NaN;
end
end
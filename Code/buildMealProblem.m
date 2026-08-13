function [solution, expressions, cvx_status] = buildMealProblem(data, config, previousMenus, bestQualityValue, randomPenalty)
% CVX meal model

R = data.NumberOfRecipes;
I = data.NumberOfIngredients;
D = data.NumberOfDays;
M = data.NumberOfMeals;
recipes = data.Recipes;

% Meal upper bounds
allowedByMeal = [recipes.AllowedBreakfast, recipes.AllowedLunch, recipes.AllowedDinner];
upperBoundZ = repmat(reshape(allowedByMeal, [R, 1, M]), [1, D, 1]);

% Reset CVX state
cvx_clear; 

cvx_begin quiet
    % SDPT3 solver
    cvx_solver sdpt3; 

    % Low precision
    cvx_precision low; 

    % Solver limits
    cvx_solver_settings('maxit', 50); % Max iterations
    cvx_solver_settings('gaptol', 1e-4); % Gap tolerance
    cvx_solver_settings('inftol', 1e-5); % Feasibility tolerance
    % Continuous relaxation
    variable z(R, D, M)
    variable q(I, 1)
    variable waste(I, 1) nonnegative

    
    % R x 1 totals
    expression z_total_recipe
    z_total_recipe = reshape(sum(sum(z, 2), 3), R, 1);
    
    % R x D daily
    expression z_daily_recipe
    z_daily_recipe = reshape(sum(z, 3), R, D);

    % I x 1 usage
    expression ingredientUse(I, 1)
    ingredientUse = data.RecipeIngredientMatrix * z_total_recipe;

    % Scalar cost
    expression costExpression
    costExpression = data.CurrentPrice' * q;

    % Nutrients x D
    expression dailyNutrients(size(data.NutrientMatrix, 1), D)
    dailyNutrients = data.NutrientMatrix * z_daily_recipe;

    % D x 1 prep
    expression dailyPreparationTime(D, 1)
    dailyPreparationTime = (recipes.PrepTime_min' * z_daily_recipe)';

    % Scalar cuisine count
    chineseRecipeIndex = find(recipes.Cuisine == "Chinese");
    expression chineseLunchDinnerCount
    chineseLunchDinnerCount = sum(sum(sum(z(chineseRecipeIndex, :, 2:3))));

    % Scalar preference penalty
    normalizedPenalty = (5 - recipes.Preference_1to5) / 4; % R x 1
    expression preferencePenalty
    preferencePenalty = normalizedPenalty' * z_total_recipe;

    % Scalar waste and prep
    expression wasteExpression
    wasteExpression = sum(waste ./ data.Ingredients.PackageSize_g);

    expression preparationExpression
    preparationExpression = sum(dailyPreparationTime);

    % Scalar quality
    expression qualityExpression
    qualityExpression = costExpression + 0.6 * wasteExpression + 0.03 * preparationExpression + 0.55 * preferencePenalty;

    % Random tie-break
    expression randomTieBreakExpression
    randomTieBreakExpression = 0;
    if ~isempty(randomPenalty)
        randomTieBreakExpression = sum(sum(sum(randomPenalty .* z)));
    end

    % Objective
    minimize( qualityExpression + config.PreferenceNoiseWeight * randomTieBreakExpression )

    % Model constraints
    subject to
        % Relaxed bounds
        z >= 0;
        z <= upperBoundZ; % Includes z <= 1
        q >= 0;
        q <= 10 * D;
        waste <= data.Ingredients.PackageSize_g .* q;
        % One recipe per meal
        for dayIndex = 1:D
            for mealIndex = 1:M
                sum(z(:, dayIndex, mealIndex)) == 1;
            end
        end

        % Inventory balance
        data.Ingredients.PackageSize_g .* q == ingredientUse + waste;

        % Budget limit
        costExpression <= config.WeeklyBudget_CAD;

        % Nutrient bounds
        dailyNutrients(1, :) >= config.CaloriesMin;
        dailyNutrients(1, :) <= config.CaloriesMax;
        dailyNutrients(2, :) >= config.ProteinMin_g;
        dailyNutrients(3, :) >= config.CarbsMin_g;
        dailyNutrients(3, :) <= config.CarbsMax_g;
        dailyNutrients(4, :) >= config.FatMin_g;
        dailyNutrients(4, :) <= config.FatMax_g;
        dailyNutrients(5, :) <= config.SugarMax_g;
        dailyNutrients(6, :) >= config.FiberMin_g;
        dailyNutrients(7, :) <= config.SodiumMax_mg;

        % Cuisine frequency
        chineseLunchDinnerCount >= config.ChineseLunchDinnerMin;
        chineseLunchDinnerCount <= config.ChineseLunchDinnerMax;

        % Weekly usage limits
        z_total_recipe <= recipes.MaxWeeklyUses;

        % No adjacent repeats
        for dayIndex = 1:(D - 1)
            for mealIndex = 1:M
                z(:, dayIndex, mealIndex) + z(:, dayIndex + 1, mealIndex) <= 1;
            end
        end

        % Preparation limits
        for dayIndex = 1:D
            if mod(dayIndex, 7) == 6 || mod(dayIndex, 7) == 0
                dailyPreparationTime(dayIndex) <= config.WeekendPrepLimit_min;
            else
                dailyPreparationTime(dayIndex) <= config.WeekdayPrepLimit_min;
            end
        end

        % Protein diversity
        proteinTypes = unique(recipes.MainProtein);
        proteinTypes(proteinTypes == "None") = [];
        for proteinIndex = 1:numel(proteinTypes)
            matchingRecipes = find(recipes.MainProtein == proteinTypes(proteinIndex));
            sum(sum(sum(z(matchingRecipes, :, 2:3)))) <= config.MaxSameProteinLunchDinner;
        end

        % No-good cuts
        if ~isempty(previousMenus)
            for previousIndex = 1:numel(previousMenus)
                previousZ = previousMenus(previousIndex).Z;
                sum(sum(sum(previousZ .* z))) <= (D * M) - config.MinimumMealChanges;
            end
        end

        % Near-optimal bound
        if ~isempty(bestQualityValue)
            qualityExpression <= bestQualityValue * (1 + config.NearOptimalTolerance);
        end
cvx_end

cvx_status = cvx_status;

% Return full arrays
if contains(cvx_status, 'Solved') || contains(cvx_status, 'Optimal') || contains(cvx_status, 'Inaccurate')
    solution.z = full(z);
    solution.q = full(q);
    solution.waste = full(waste);

    expressions.Quality = full(qualityExpression);
    expressions.Cost = full(costExpression);
    expressions.IngredientUse = full(ingredientUse);
    expressions.DailyNutrients = full(dailyNutrients);
    expressions.ChineseLunchDinnerCount = full(chineseLunchDinnerCount);
    expressions.DailyPreparationTime = full(dailyPreparationTime);
else
    solution = [];
    expressions = struct();
end
end
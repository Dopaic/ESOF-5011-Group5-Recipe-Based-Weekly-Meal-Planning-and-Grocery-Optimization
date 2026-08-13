function runMealPlanner()
% Main entry point

clc;

% Project root
projectRoot = fileparts(mfilename('fullpath'));
dataFile = fullfile(projectRoot, 'data', 'meal_planner_data.xlsx');

% Data workbook
if ~isfile(dataFile)
    error('Data file not found: %s', dataFile);
end

fprintf('\n============================================================\n');
fprintf(' Recipe-Based Weekly Meal Planning and Grocery Optimization\n');
fprintf('============================================================\n');

while true
    fprintf('\nChoose an action:\n');
    fprintf('  1 - Generate a weekly menu and shopping list\n');
    fprintf('  2 - Add a new recipe interactively\n');
    fprintf('  3 - Add or update a monthly price scenario\n');
    fprintf('  4 - List current recipes\n');
    fprintf('  5 - Validate the data workbook\n');
    fprintf('  0 - Exit\n');

    choice = str2double(input('Selection: ', 's'));

    switch choice
        case 1
            % Runtime settings
            config = getRunConfiguration(dataFile);

            % Price vector
            data = loadMealData(dataFile, config.SelectedMonth);

            % Input validation
            validateMealData(data, config);

            % Candidate pool
            [menuPool, selectedIndex, runInfo] = generateMenuPool(data, config);

            if isempty(menuPool)
                error(['No feasible menu was found. Try increasing the budget, ' ...
                    'relaxing nutrition limits, or reducing the diversity level.']);
            end

            selectedCandidate = menuPool(selectedIndex);

            % Export results
            outputFiles = exportMealPlan(selectedCandidate, menuPool, data, config, runInfo, projectRoot);

            fprintf('\nSelected candidate: %d of %d\n', selectedIndex, numel(menuPool));
            fprintf('Estimated grocery cost: CAD %.2f\n', selectedCandidate.TotalCost);
            fprintf('Chinese lunches/dinners: %d of 14\n', selectedCandidate.ChineseLunchDinnerCount);
            fprintf('Output workbook: %s\n', outputFiles.ExcelFile);
            fprintf('Text summary: %s\n', outputFiles.TextFile);

        case 2
            % Add recipe
            addRecipeInteractive(dataFile);

        case 3
            % Monthly prices
            updateMonthlyPricesInteractive(dataFile);

        case 4
            % Recipe review
            listRecipes(dataFile);

        case 5
            % Workbook validation
            settings = loadSettings(dataFile);
            data = loadMealData(dataFile, settings.SelectedMonth);
            validateMealData(data, settings);
            fprintf('Data validation completed successfully.\n');

        case 0
            fprintf('Program closed.\n');
            return;

        otherwise
            fprintf('Invalid selection. Please enter 0 to 5.\n');
    end
end
end

function config = getRunConfiguration(dataFile)
% Runtime settings

config = loadSettings(dataFile);

fprintf('\nDefault settings:\n');
fprintf('  Price month: %s\n', char(config.SelectedMonth));
fprintf('  Weekly budget: CAD %.2f\n', config.WeeklyBudget_CAD);
fprintf('  Candidate menus: %d\n', config.CandidateMenus);
fprintf('  Minimum meal changes: %d\n', config.MinimumMealChanges);

answer = lower(strtrim(input('Use these default settings? [Y/n]: ', 's')));
if isempty(answer) || strcmp(answer, 'y') || strcmp(answer, 'yes')
    return;
end

monthInput = strtrim(input(sprintf('Price month [%s]: ', char(config.SelectedMonth)), 's'));
if ~isempty(monthInput)
    config.SelectedMonth = string(monthInput);
end

budgetInput = strtrim(input(sprintf('Weekly budget [%.2f]: ', config.WeeklyBudget_CAD), 's'));
if ~isempty(budgetInput)
    newBudget = str2double(budgetInput);
    if isfinite(newBudget) && newBudget > 0
        config.WeeklyBudget_CAD = newBudget;
    end
end

fprintf('\nDiversity level:\n');
fprintf('  1 - Low: menus stay close to the mathematical optimum\n');
fprintf('  2 - Medium: balanced cost and variety\n');
fprintf('  3 - High: more menu changes, with a wider near-optimal range\n');
level = str2double(input('Diversity level [2]: ', 's'));
if isnan(level)
    level = 2;
end

switch level
    case 1
        config.CandidateMenus = 6;
        config.NearOptimalTolerance = 0.03;
        config.MinimumMealChanges = 2;
        config.PreferenceNoiseWeight = 0.04;
    case 3
        config.CandidateMenus = 15;
        config.NearOptimalTolerance = 0.09;
        config.MinimumMealChanges = 6;
        config.PreferenceNoiseWeight = 0.15;
    otherwise
        config.CandidateMenus = 10;
        config.NearOptimalTolerance = 0.06;
        config.MinimumMealChanges = 4;
        config.PreferenceNoiseWeight = 0.08;
end

seedInput = strtrim(input('Random seed [0 = automatic]: ', 's'));
if ~isempty(seedInput)
    newSeed = str2double(seedInput);
    if isfinite(newSeed) && newSeed >= 0
        config.RandomSeed = newSeed;
    end
end
end

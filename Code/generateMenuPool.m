function [menuPool, selectedIndex, runInfo] = generateMenuPool(data, config)
if config.RandomSeed == 0
    rng('shuffle');
else
    rng(config.RandomSeed, 'twister');
end

menuPool = struct([]);
previousMenus = struct([]);
solverMessages = strings(0, 1);
rejectedCandidates = 0;
referenceRecoveredQuality = [];

zeroPenalty = zeros(data.NumberOfRecipes, data.NumberOfDays, data.NumberOfMeals);
[solution, expressions, cvx_status] = buildMealProblem(data, config, previousMenus, [], zeroPenalty);

if isempty(solution)
    selectedIndex = [];
    runInfo = struct('Messages', "No feasible base solution", 'BestQuality', NaN, ...
        'RelaxedBestQuality', NaN, 'NumberOfCandidates', 0, 'SelectedIndex', [], ...
        'RejectedCandidates', 0, 'GeneratedAt', datetime('now'));
    return;
end

bestRelaxedQuality = full(expressions.Quality);
baseCandidate = summarizeCandidate(solution, expressions, data, config);
[baseValid, ~] = validateCandidate(baseCandidate, data, config, false);
if baseValid
    baseCandidate.ExitFlag = 1;
    baseCandidate.SolverMessage = string(cvx_status);
    menuPool = baseCandidate;
    previousMenus = menuPool;
    referenceRecoveredQuality = baseCandidate.QualityValue;
    solverMessages(end + 1, 1) = string(cvx_status);
else
    rejectedCandidates = rejectedCandidates + 1;
end

maxAttempts = max(30, config.CandidateMenus * 10);
attemptIndex = 0;
while numel(menuPool) < config.CandidateMenus && attemptIndex < maxAttempts
    attemptIndex = attemptIndex + 1;
    adjustedConfig = config;
    reduction = mod(attemptIndex - 1, 3);
    adjustedConfig.MinimumMealChanges = max(1, config.MinimumMealChanges - reduction);
    randomPenalty = rand(data.NumberOfRecipes, data.NumberOfDays, data.NumberOfMeals);

    [solution, expressions, cvx_status] = buildMealProblem(data, adjustedConfig, previousMenus, bestRelaxedQuality, randomPenalty);
    if isempty(solution) || ~(contains(cvx_status, 'Solved') || contains(cvx_status, 'Optimal') || contains(cvx_status, 'Inaccurate'))
        continue;
    end

    candidate = summarizeCandidate(solution, expressions, data, adjustedConfig);
    [isValid, ~] = validateCandidate(candidate, data, adjustedConfig, false);
    if ~isValid
        rejectedCandidates = rejectedCandidates + 1;
        continue;
    end

    if ~isempty(referenceRecoveredQuality)
        if candidate.QualityValue > referenceRecoveredQuality * (1 + config.NearOptimalTolerance) + 1e-8
            rejectedCandidates = rejectedCandidates + 1;
            continue;
        end
    end

    if ~isDifferentEnough(candidate, menuPool, adjustedConfig.MinimumMealChanges, data.NumberOfDays * data.NumberOfMeals)
        rejectedCandidates = rejectedCandidates + 1;
        continue;
    end

    candidate.ExitFlag = 1;
    candidate.SolverMessage = string(cvx_status);
    menuPool(end + 1) = candidate;
    previousMenus = menuPool;
    solverMessages(end + 1, 1) = string(cvx_status);

    if isempty(referenceRecoveredQuality)
        referenceRecoveredQuality = candidate.QualityValue;
    else
        referenceRecoveredQuality = min(referenceRecoveredQuality, candidate.QualityValue);
    end
end

if isempty(menuPool)
    selectedIndex = [];
    runInfo.BestQuality = NaN;
    runInfo.RelaxedBestQuality = bestRelaxedQuality;
    runInfo.NumberOfCandidates = 0;
    runInfo.SelectedIndex = [];
    runInfo.Messages = solverMessages;
    runInfo.RejectedCandidates = rejectedCandidates;
    runInfo.GeneratedAt = datetime('now');
    return;
end

selectedIndex = randi(numel(menuPool));
runInfo.BestQuality = min([menuPool.QualityValue]);
runInfo.RelaxedBestQuality = bestRelaxedQuality;
runInfo.NumberOfCandidates = numel(menuPool);
runInfo.SelectedIndex = selectedIndex;
runInfo.Messages = solverMessages;
runInfo.RejectedCandidates = rejectedCandidates;
runInfo.GeneratedAt = datetime('now');
end

function isDifferent = isDifferentEnough(candidate, menuPool, minimumChanges, totalMeals)
isDifferent = true;
if isempty(menuPool)
    return;
end

for candidateIndex = 1:numel(menuPool)
    sameMeals = sum(candidate.Z .* menuPool(candidateIndex).Z, 'all');
    changedMeals = totalMeals - sameMeals;
    if changedMeals < minimumChanges
        isDifferent = false;
        return;
    end
end
end

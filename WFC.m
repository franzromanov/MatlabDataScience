

NUM_TRIALS = 50; % number of trials per strategy

results = struct();
results.random.success   = 0;
results.random.times     = zeros(1, NUM_TRIALS);
results.smallest.success = 0;
results.smallest.times   = zeros(1, NUM_TRIALS);

fprintf('Running %d trials for each strategy...\n', NUM_TRIALS);

%% ---- Strategy 1: RANDOM cell selection ----
for trial = 1:NUM_TRIALS
    t_start = tic;
    [grid, ok] = run_wfc('random');
    results.random.times(trial) = toc(t_start);
    if ok
        results.random.success = results.random.success + 1;
    end
end

%% ---- Strategy 2: SMALLEST-DOMAIN cell selection ----
for trial = 1:NUM_TRIALS
    t_start = tic;
    [grid, ok] = run_wfc('smallest');
    results.smallest.times(trial) = toc(t_start);
    if ok
        results.smallest.success = results.smallest.success + 1;
    end
end

%% ---- Print Results ----
fprintf('\n========== PROBABILITY / CONVERGENCE ANALYSIS ==========\n');
fprintf('Strategy          | Success Rate | Avg Time (s)\n');
fprintf('------------------+--------------+--------------\n');
fprintf('Random Cell       | %5.1f %%      | %.6f\n', ...
    results.random.success  / NUM_TRIALS * 100, mean(results.random.times));
fprintf('Smallest Domain   | %5.1f %%      | %.6f\n', ...
    results.smallest.success / NUM_TRIALS * 100, mean(results.smallest.times));

%% ---- Show one valid board (smallest-domain strategy) ----
fprintf('\nSample Sudoku board (Smallest-Domain strategy):\n');
[final_grid, ~] = run_wfc('smallest');
disp(final_grid);


% =========================================================
%  FUNCTION: run_wfc
%  Runs one complete WFC attempt.
%  strategy : 'random'   -> pick any uncollapsed cell at random
%             'smallest' -> pick cell with fewest candidates (MRV)
%  Returns  : grid (9x9 double), success (logical)
% =========================================================
function [grid, success] = run_wfc(strategy)
    MAX_ITER = 9 * 9;

    % Initialise domains: every cell can be 1..9
    domains = cell(9, 9);
    for r = 1:9
        for c = 1:9
            domains{r, c} = 1:9;
        end
    end

    grid      = zeros(9, 9);
    perulangan = 0;
    success   = false;

    while perulangan < MAX_ITER
        % Build domain-length matrix
        lens = cellfun(@length, domains);

        % ---- Cell selection ----
        if strcmp(strategy, 'smallest')
            % MRV: choose cell with smallest non-zero domain
            search_lens = lens;
            search_lens(lens == 0) = Inf;   % skip already collapsed cells
            [minL, idx] = min(search_lens(:));
            if isinf(minL)
                break;   % all cells collapsed -> done
            end
            [row, col] = ind2sub([9, 9], idx(1));

        else  % 'random'
            % Find all uncollapsed cells (domain > 0 but cell not yet set)
            open_mask = (lens > 0) & (grid == 0);
            if ~any(open_mask(:))
                break;   % all cells set -> done
            end
            open_idx = find(open_mask);
            idx      = open_idx(randi(numel(open_idx)));
            [row, col] = ind2sub([9, 9], idx);
            minL     = lens(row, col);
        end

        dom = domains{row, col};

        % Contradiction: no candidates left for this cell
        if isempty(dom)
            return;   % failure
        end

        % Collapse: pick a value
        if minL == 1
            pick = dom;          % only one option, no need to sample
        else
            pick = dom(randi(numel(dom)));
        end

        grid(row, col)    = pick;
        domains{row, col} = [];  % mark as collapsed (empty = done)

        % Propagate constraints
        domains = propagate_constraints(domains, row, col, pick);

        perulangan = perulangan + 1;
    end

    % Validate the finished grid
    if all(grid(:) ~= 0) && is_valid_sudoku(grid)
        success = true;
    end
end


% =========================================================
%  FUNCTION: propagate_constraints
%  After collapsing cell (row, col) to value 'pick',
%  remove 'pick' from:
%    1. All cells in the same ROW
%    2. All cells in the same COLUMN
%    3. All cells in the same 3x3 BOX
% =========================================================
function domains = propagate_constraints(domains, row, col, pick)

    %% 1. Cek kesamaan angka BARIS (row constraint)
    for c = 1:9
        if c ~= col && ~isempty(domains{row, c})
            domains{row, c} = domains{row, c}(domains{row, c} ~= pick);
        end
    end

    %% 2. Cek kesamaan angka KOLOM (column constraint)
    for r = 1:9
        if r ~= row && ~isempty(domains{r, col})
            domains{r, col} = domains{r, col}(domains{r, col} ~= pick);
        end
    end

    %% 3. Cek kesamaan angka LOCAL GRID 3x3 (box constraint)
    box_row_start = 3 * floor((row - 1) / 3) + 1;  % top-left row of 3x3 box
    box_col_start = 3 * floor((col - 1) / 3) + 1;  % top-left col of 3x3 box

    for r = box_row_start : box_row_start + 2
        for c = box_col_start : box_col_start + 2
            if (r ~= row || c ~= col) && ~isempty(domains{r, c})
                domains{r, c} = domains{r, c}(domains{r, c} ~= pick);
            end
        end
    end
end


% =========================================================
%  FUNCTION: is_valid_sudoku
%  Verifies a completed 9x9 grid is a legal Sudoku solution.
% =========================================================
function valid = is_valid_sudoku(grid)
    valid  = true;
    target = sort(1:9);

    for i = 1:9
        % Check row
        if ~isequal(sort(grid(i, :)), target)
            valid = false; return;
        end
        % Check column
        if ~isequal(sort(grid(:, i)'), target)
            valid = false; return;
        end
    end

    % Check each 3x3 box
    for br = 0:2
        for bc = 0:2
            box = grid(br*3+1:br*3+3, bc*3+1:bc*3+3);
            if ~isequal(sort(box(:)'), target)
                valid = false; return;
            end
        end
    end
end

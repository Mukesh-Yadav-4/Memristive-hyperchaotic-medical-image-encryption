function [scramble_idx, method_name] = scramble_engine(method, H, W, session_key)
% SCRAMBLE_ENGINE - Modular Spatial Permutation Engine for Image Cryptography
%
% Supported Methods:
%   'josephus'     - Cross-ring concentric Josephus elimination (Paper framework)
%   'arnold'       - 2D Arnold Cat Map (Area-preserving chaotic torus map)
%   'zigzag'       - Diagonal Zigzag geometric scanline disperser
%   'm4dchs_sort'  - 4D Memristive Hyperchaotic coordinate sort
%
% Output:
%   scramble_idx - 1D permutation index vector of length (H * W)
%
% Invertibility Guarantee:
%   [~, inv_idx] = sort(scramble_idx);
%   restored_plane = scrambled_plane(inv_idx);
%
% Author: Yash (OIST Research Portfolio)

    total_pixels = H * W;
    if nargin < 4 || isempty(session_key)
        session_key = 0.12345678;
    end

    switch lower(strtrim(method))
        case {'josephus', 'cross_ring_josephus'}
            method_name = 'Cross-Ring Josephus Scrambling';
            step_m = max(3, round(session_key * 23)); % Dynamic step from key
            scramble_idx = [];

            num_rings = floor(min(H, W) / 2);
            for r = 1:num_rings
                top    = sub2ind([H, W], repmat(r, 1, W - 2*r + 1), r:W-r);
                right  = sub2ind([H, W], r:H-r, repmat(W-r+1, 1, H - 2*r + 1));
                bottom = sub2ind([H, W], repmat(H-r+1, 1, W - 2*r + 1), W-r+1:-1:r+1);
                left   = sub2ind([H, W], H-r+1:-1:r+1, repmat(r, 1, H - 2*r + 1));

                ring = unique([top, right, bottom, left], 'stable');
                curr = 1;
                while ~isempty(ring)
                    curr = mod(curr + step_m - 1, length(ring)) + 1;
                    scramble_idx = [scramble_idx, ring(curr)];
                    ring(curr) = [];
                end
            end
            % If odd dimension center pixel remains
            if length(scramble_idx) < total_pixels
                remaining = setdiff(1:total_pixels, scramble_idx, 'stable');
                scramble_idx = [scramble_idx, remaining];
            end
            scramble_idx = scramble_idx(:);

        case {'arnold', 'arnold_cat', 'acm'}
            method_name = '2D Arnold Cat Map (ACM)';
            p = 3; q = 5; iters = 4;
            N = max(H, W);
            [X, Y] = meshgrid(0:N-1, 0:N-1);
            X = X(:); Y = Y(:);
            for it = 1:iters
                X_new = mod(X + p * Y, N);
                Y_new = mod(q * X + (p * q + 1) * Y, N);
                X = X_new; Y = Y_new;
            end
            full_idx = Y * N + X + 1;
            valid_mask = (full_idx <= total_pixels);
            scramble_idx = full_idx(valid_mask);
            if length(scramble_idx) < total_pixels
                rem = setdiff(1:total_pixels, scramble_idx, 'stable');
                scramble_idx = [scramble_idx; rem(:)];
            end
            scramble_idx = scramble_idx(1:total_pixels);

        case 'zigzag'
            method_name = 'Diagonal Zigzag Scanning';
            idx_grid = reshape(1:total_pixels, [H, W]);
            scramble_idx = [];
            for d = 2:(H + W)
                if mod(d, 2) == 0
                    for r = max(1, d - W):min(H, d - 1)
                        scramble_idx = [scramble_idx, idx_grid(r, d - r)];
                    end
                else
                    for r = min(H, d - 1):-1:max(1, d - W)
                        scramble_idx = [scramble_idx, idx_grid(r, d - r)];
                    end
                end
            end
            scramble_idx = scramble_idx(:);

        case {'m4dchs_sort', 'chaotic_sort', 'default'}
            method_name = '4D Memristive Hyperchaotic Permutation';
            [~, states] = m4dchs_engine(session_key, total_pixels, 200);
            % Sort along the memristive variable w
            [~, scramble_idx] = sort(states(:, 4));
            scramble_idx = scramble_idx(:);

        otherwise
            error('Unknown scrambling method: %s. Choose: josephus, arnold, zigzag, m4dchs_sort', method);
    end
end

function [keystream, states] = m4dchs_engine(session_key, num_bytes, discard_steps)
% M4DCHS_ENGINE - 4-Dimensional Memristive Hyperchaotic Keystream Generator
%
% Dynamical Equations:
%   dx/dt = a*(y - x) + w
%   dy/dt = c*x - x*z + d*y
%   dz/dt = x*y - b*z
%   dw/dt = -r*x - k*(alpha + 3*beta*x^2)*w
%
% Parameters (Verified Hyperchaotic Regime):
%   a = 15.81, b = 2.76, c = 86.03, d = -9.07, r = 10.79
%   k = 0.05, alpha = 0.8, beta = 0.02
%
% Author: Yash (OIST Research Portfolio)

    if nargin < 3 || isempty(discard_steps)
        discard_steps = 500; % Discard transient phase to settle onto attractor
    end

    % Hyperchaotic system parameters
    a = single(15.81);
    b = single(2.76);
    c = single(86.03);
    d = single(-9.07);
    r = single(10.79);
    k = single(0.05);
    alpha = single(0.8);
    beta  = single(0.02);

    dt = single(0.001);
    dt_half  = single(0.5 * dt);
    dt_sixth = single(dt / 6.0);

    % Initial conditions parameterized by the dynamic session key
    k_val = single(session_key);
    x = single(1.0 + k_val);
    y = single(1.0 + k_val);
    z = single(20.0 + k_val * 5.0);
    w = single(0.5 + k_val);

    % Transient burn-in
    for step = 1:discard_steps
        dx1 = a*(y - x) + w;
        dy1 = c*x - x*z + d*y;
        dz1 = x*y - b*z;
        dw1 = -r*x - k*(alpha + 3.0*beta*x*x)*w;

        x2 = x + dt_half*dx1; y2 = y + dt_half*dy1; z2 = z + dt_half*dz1; w2 = w + dt_half*dw1;
        dx2 = a*(y2 - x2) + w2; dy2 = c*x2 - x2*z2 + d*y2; dz2 = x2*y2 - b*z2; dw2 = -r*x2 - k*(alpha + 3.0*beta*x2*x2)*w2;

        x3 = x + dt_half*dx2; y3 = y + dt_half*dy2; z3 = z + dt_half*dz2; w3 = w + dt_half*dw2;
        dx3 = a*(y3 - x3) + w3; dy3 = c*x3 - x3*z3 + d*y3; dz3 = x3*y3 - b*z3; dw3 = -r*x3 - k*(alpha + 3.0*beta*x3*x3)*w3;

        x4 = x + dt*dx3; y4 = y + dt*dy3; z4 = z + dt*dz3; w4 = w + dt*dw3;
        dx4 = a*(y4 - x4) + w4; dy4 = c*x4 - x4*z4 + d*y4; dz4 = x4*y4 - b*z4; dw4 = -r*x4 - k*(alpha + 3.0*beta*x4*x4)*w4;

        x = x + dt_sixth*(dx1 + 2.0*dx2 + 2.0*dx3 + dx4);
        y = y + dt_sixth*(dy1 + 2.0*dy2 + 2.0*dy3 + dy4);
        z = z + dt_sixth*(dz1 + 2.0*dz2 + 2.0*dz3 + dz4);
        w = w + dt_sixth*(dw1 + 2.0*dw2 + 2.0*dw3 + dw4);
    end

    % Main keystream extraction
    keystream = zeros(num_bytes, 1, 'uint8');
    states = zeros(num_bytes, 4, 'single');

    for i = 1:num_bytes
        % Quantization: Memristive dual-state extraction
        abs_val = single(abs((x + y) * 1.0e6));
        keystream(i) = uint8(bitand(uint32(floor(abs_val)), uint32(255)));
        states(i, :) = [x, y, z, w];

        % RK4 Step
        dx1 = a*(y - x) + w;
        dy1 = c*x - x*z + d*y;
        dz1 = x*y - b*z;
        dw1 = -r*x - k*(alpha + 3.0*beta*x*x)*w;

        x2 = x + dt_half*dx1; y2 = y + dt_half*dy1; z2 = z + dt_half*dz1; w2 = w + dt_half*dw1;
        dx2 = a*(y2 - x2) + w2; dy2 = c*x2 - x2*z2 + d*y2; dz2 = x2*y2 - b*z2; dw2 = -r*x2 - k*(alpha + 3.0*beta*x2*x2)*w2;

        x3 = x + dt_half*dx2; y3 = y + dt_half*dy2; z3 = z + dt_half*dz2; w3 = w + dt_half*dw2;
        dx3 = a*(y3 - x3) + w3; dy3 = c*x3 - x3*z3 + d*y3; dz3 = x3*y3 - b*z3; dw3 = -r*x3 - k*(alpha + 3.0*beta*x3*x3)*w3;

        x4 = x + dt*dx3; y4 = y + dt*dy3; z4 = z + dt*dz3; w4 = w + dt*dw3;
        dx4 = a*(y4 - x4) + w4; dy4 = c*x4 - x4*z4 + d*y4; dz4 = x4*y4 - b*z4; dw4 = -r*x4 - k*(alpha + 3.0*beta*x4*x4)*w4;

        x = x + dt_sixth*(dx1 + 2.0*dx2 + 2.0*dx3 + dx4);
        y = y + dt_sixth*(dy1 + 2.0*dy2 + 2.0*dy3 + dy4);
        z = z + dt_sixth*(dz1 + 2.0*dz2 + 2.0*dz3 + dz4);
        w = w + dt_sixth*(dw1 + 2.0*dw2 + 2.0*dw3 + dw4);
    end
end

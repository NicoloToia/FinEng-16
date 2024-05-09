% runAssignment7_Group16
%  group 16, AY2023-2024
% 
%
% to run:
% > runAssignment7_Group16

clc
clear all
close all

tic

% fix random seed
rng(42) 

%% Add the directories to the path

addpath('Data');
addpath('Discounts');
addpath('FFT');
addpath('pricing')
addpath('Tree')
addpath('schemes')


%% Load data for bootstrap and NIG model

%discount factors
load('discounts.mat');
load('calibrated_parameters.mat');
load('EuroStoxx_data.mat');

%% Data for exercise 1

principal = 100e6; % 100 million
ttm = 2; % 2 years
coupon_1y = 6 / 100;
coupon_2y = 2 / 100;
s_A = 1.3 / 100;
strike = 3200; 
trigger = 6 / 100;

% initial price and parameters for the NIG
S_0 = cSelect.reference;
d = cSelect.dividend;
alpha = 1/2;
sigma = calibrated_parameters(1);
kappa = calibrated_parameters(2);
eta = calibrated_parameters(3);

%% Compute upfront mc

N = 1e6;

X = computeUpfrontMCV(S_0, d, strike, ttm, principal, coupon_1y, coupon_2y, s_A, sigma, kappa, eta, ...
    discounts, dates, alpha, N);

% print the upfront payment
disp('--- Upfront payment of the Certificate ---')
disp(['The upfront payment is: ', num2str(X/principal*100), '%']);
disp(['The upfront payment is: ', num2str(X), ' EUR']);
disp('--- --- ---')

%%
X = Compute_Upfront_Closed(S_0, d, strike, 2, principal, coupon_1y, coupon_2y, s_A, sigma, kappa, eta, ...
    discounts, dates, alpha);

% print the upfront
disp('--- Upfront payment of the Certificate computed via close integral formula ---')
disp(['The upfront payment is: ', num2str(X/principal*100), '%']);
disp(['The upfront payment is: ', num2str(X), ' EUR']);
disp('--- --- ---')



%% Compute the upfront payment

X_NIG = computeUpfrontFFT(S_0, d, strike, ttm, principal, coupon_1y, coupon_2y, s_A, sigma, kappa, eta, discounts, dates, alpha);

% print the upfront payment percentage
disp('--- Upfront payment of the Certificate ---')
disp(['The upfront payment is: ', num2str(X_NIG/principal*100), '%']);
disp(['The upfront payment is: ', num2str(X_NIG), ' EUR']);
disp('--- --- ---')

%% Compute the upfront payment via Variance Gamma

% % % load('calibrated_parameters_gamma.mat')
% % % 
% % % alpha = 0;
% % % sigma = calibrated_parameters_gamma(1);
% % % kappa = calibrated_parameters_gamma(2);
% % % eta = calibrated_parameters_gamma(3);
% % % 
% % % X_VG = computeUpfrontFFT(S_0, d, strike, ttm, principal, coupon_1y, coupon_2y, s_A, sigma, kappa, eta, discounts, dates, alpha);
% % % 
% % % % print the upfront payment percentage
% % % disp('--- Upfront payment of the Certificate VG---')
% % % disp(['The upfront payment is: ', num2str(X_VG/principal*100), '%']);
% % % disp(['The upfront payment is: ', num2str(X_VG), ' EUR']);
% % % disp('--- --- ---')


%% Black con Skew

% save the data to use
quoted_strikes = cSelect.strikes;
quoted_vols = cSelect.surface;

flag = 2; % Black with skew

X_black_skew = computeUpfrontSkew(S_0, d, strike, ttm, principal, coupon_1y, coupon_2y, s_A, discounts, dates, ...
    quoted_strikes, quoted_vols, flag);

% print the upfront payment percentage
disp('--- Upfront payment of the Certificate via Black adj skew---')
disp(['The upfront payment is: ', num2str(X_black_skew/principal*100), '%']);
disp(['The upfront payment is: ', num2str(X_black_skew), ' EUR']);
disp('--- --- ---')



%% Black price without skew (no digital risk)

flag = 1; % Black without skew

X_black = computeUpfrontSkew(S_0, d, strike, ttm, principal, coupon_1y, coupon_2y, s_A, discounts, dates, ...
    quoted_strikes, quoted_vols, flag);

% find the error in the price wrt the one with skew and the one with NIG
black_vs_blackSkew = abs(X_black - X_black_skew) / X_black_skew * 100;
black_vs_NIG = abs(X_black - X_NIG) / X_NIG * 100;
blackSkew_vs_NIG = abs(X_black_skew - X_NIG) / X_NIG * 100;

% print the upfront payment percentage
disp('--- Upfront payment of the Certificate via Black---')
disp(['The upfront payment is: ', num2str(X_black/principal*100), '%']);
disp(['The upfront payment is: ', num2str(X_black), ' EUR']);
disp('--- --- ---')

disp('--- The Error using Black model (%) ---')
disp(['The error between Black without skew and adj Black   : ', num2str(black_vs_blackSkew)]);
disp(['The error between Black without skew and NIG         : ', num2str(black_vs_NIG)]);
disp(['The error between Black with skew and NIG            : ', num2str(blackSkew_vs_NIG)]);
disp('--- --- ---')

%% 3y bond
ttm = 3; 
N = 1e5; 
coupons(1) = 0.06; 
coupons(2) = 0.06; 
coupons(3) = 0.02; 

X_3y = price3y(S_0, d, strike, ttm, alpha, sigma, kappa, eta, s_A, N, discounts, dates, principal, coupons);
disp ('--- Pricing bond with expiry 3y ---')
disp(['The upfront payment is: ', num2str(X_3y/principal*100), '%']);
disp(['The price of the 3y bond is   : ', num2str(X_3y)]);
disp('--- --- ---')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Tree
% data for the tree
a = 0.11;
sigma = 0.008;
ttm = 10;

int_in_1y = 4;
dt_1y = 1/int_in_1y;
dt = dt_1y;
N_step = int_in_1y * ttm;


% compute the reset dates for the tree
tree_dates = datetime(dates(1), 'ConvertFrom', 'datenum') + calyears(1:ttm)';
% convert to business date
tree_dates(~isbusday(tree_dates,eurCalendar())) = ...
    busdate(tree_dates(~isbusday(tree_dates,eurCalendar())),'modifiedfollow',eurCalendar());
tree_dates = datenum(tree_dates);


[l_max, mu, trinomial_tree,tree_matrix] = buildTrinomialTree(a, sigma, dt, ttm);

% compute the forward discounts at each node
dates = datenum(dates);

% compute the date in each node by summing each dt

node_dates = datetime(dates(1),'convertFrom', 'datenum') + dt .* [1:N_step] * 365;
node_dates(~isbusday(tree_dates,eurCalendar())) = ...
    busdate(node_dates(~isbusday(tree_dates,eurCalendar())),'modifiedfollow',eurCalendar());
node_dates = datenum(node_dates);

node_dates = [dates(1) , node_dates]';

tree_dates = [dates(1) ; node_dates(int_in_1y.*[1:ttm]+1)];

fwd_discount_nodes = compute_fwdSpot(dates, node_dates, discounts, N_step);

resetDates = tree_dates;

fwd_spot_node = compute_fwdSpot_reset(dates, resetDates, discounts, length(resetDates)-1);

% Compute the discounts swap rate in each reset date

%discount = discount_reset(sigma , a , resetDates , node_dates , tree_matrix , fwd_spot_node , l_max , N_step , dates , ttm);

%%

ttm = 10;
int_in_1y = 1;
dt_1y = 1/int_in_1y;
dt = dt_1y;
N_step = int_in_1y * ttm;

alfa = 2;
omega=ttm;

strike_swaption = 0.05;

node_dates = datetime(dates(1),'convertFrom', 'datenum') + dt .* [1:N_step] * 365;
node_dates(~isbusday(tree_dates,eurCalendar())) = ...
    busdate(node_dates(~isbusday(tree_dates,eurCalendar())),'modifiedfollow',eurCalendar());
node_dates = datenum(node_dates);

node_dates = [dates(1) , node_dates]';

fwd_discount_nodes = compute_fwdSpot(dates, node_dates, discounts, N_step);

discounts_j = intExtDF(discounts , dates, node_dates);

discounts_j = discounts_j(2:end);

Jamshidian(alfa,omega,strike_swaption, node_dates, a, sigma, dates,discounts_j)

%% BERMUDAN SWAPTION BY THREENOMIAL TREE

% import the data
strike = 5/100; 
ttm = 10; % 10 years time to maturity
% the option can be exercided every 1 year from the 2 year (non-call 2)
% HULL-WHITE parameters
a = 11/100;
sigma = 0.8/100;

% compute the reset dates for the tree from 2 to 9 years
reset_dates = (datenum(dates(1)) + (1:ttm)*365)';

% set the number of steps in each interval
N_steps_in_1y = 150;
N_steps = N_steps_in_1y * ttm;

% find the interval length dt
dt = 1/N_steps_in_1y;

% find the dates in each node
node_dates = (datenum(dates(1)) + dt*(0:N_steps)*365)';
% find the integer for the dates
node_dates = round(node_dates);


% compute sigma hat and mu hat
mu_hat = 1- exp(-a*dt);
sigma_hat = sigma * sqrt((1-exp(-2*a*dt))/(2*a));
% find the jump D_x in the tree
D_x = sigma_hat * sqrt(3);
% find l_max and l_min (symmetric)
l_max = ceil((1-sqrt(2/3))/mu_hat);
l_min = -l_max;
% vector of position in the tree (l)     
l = l_max:-1:l_min;

% build the vector of x_i based on the indicator l
x = l * D_x;

% compute the forward discount factor in each reset date
% fwdDE_reset = zeros(2*l_max+1, length(resetDates));

discounts_reset = intExtDF(discounts, dates, reset_dates);
BPV = zeros(2*l_max+1, length(reset_dates)-1);
swaps_rate = zeros(2*l_max+1, length(reset_dates)-1);
intr_value = zeros(2*l_max+1, length(reset_dates)-1);
intr_value1 = zeros(2*l_max+1, length(reset_dates)-1);

for i = 2:9

    fwdDF_ttm = discounts_reset(end)/discounts_reset(i);
    fwdDF_present = fwdDF_ttm*exp( -x * (sigmaHJM(a, sigma, (ttm-i), 0)/sigma) - 0.5 * IntHJM(a, sigma, i, 0, (i-1) ) );
    float_leg = (1 - fwdDF_present)';
    % find the BPV
    fwdDF_dt = discounts_reset(i+1:end)/discounts_reset(i);
    BPV = 0;

    for j = 1:ttm-i
        fwdDF_present_dt = fwdDF_dt(j) * exp( -x * (sigmaHJM(a, sigma, (i+j), 0)/sigma) - 0.5 * IntHJM(a, sigma, i, 0, (i-1)) );
        BPV = BPV + fwdDF_present_dt'; % is an yearly bpv so delta_i is always 1
    end

%     BPV = BPV(:,i)
    % find the swap rates
    swaps_rate(:,i) = float_leg ./ BPV;

    intr_value1(:,i) = max(0, 1 - BPV * strike + fwdDF_present');
    intr_value(:,i) = BPV .* max(0, swaps_rate(:,i) - strike);

end

% Build the tree to keep trace of zeros and 1 in the scheme
Tree_matrix = zeros(2*l_max+1, ttm);
Tree_matrix(l_max + 1, 1) = 1;

for i = 2:ttm

    if i <= l_max + 1

        Tree_matrix(:,i) = Tree_matrix(:,i-1);    
        Tree_matrix(l_max + 2 - i  , i) = 1;
        
        Tree_matrix(l_max + i , i) = 1;
    else
        Tree_matrix(:,i) = Tree_matrix(:,i-1);
    end

end


% for i = 1:ttm-1
%    intr_value(:,i) = intr_value(:,i) .* Tree_matrix(:,i+1);
% end

%% Build the tree with the stochastic dicount in each node for the step (i, i+1)

discounts_node = intExtDF(discounts, dates, node_dates);
discounts_node(1) = 1;
fwd_discount_nodes = discounts_node(2:end)./discounts_node(1:end-1);
sigma_star = (sigma/a) * sqrt(dt - 2 *( (1 - exp(-a*dt)) / a ) + (1 - exp(-2*a*dt)) / (2*a) );

% initialize
fwdDF_present = zeros(2*l_max+1, N_steps);

for i = 1:N_steps

    fwdDF_present(:,i) = fwd_discount_nodes(i)*exp( -x * (sigmaHJM(a, sigma, dt, 0)/sigma) - 0.5 * IntHJM(a, sigma, i, 0, dt) );
     
    % Compute the stochastic discounts in each node
%     for j = 1:2*l_max+1
%         fwdSDF_present = fwdDF_present(j) * exp( -0.5*sigma_star^2 + (sigma_star/sigma_hat)*(exp(-a*dt) ) );
%     end
end

value = zeros(2*l_max + 1, (ttm)*N_steps_in_1y+1 );

for i = (ttm)*N_steps_in_1y:-1:1

    % compute the continuation value
    for j = 1:2*l_max+1

        if j == 1
            value(j,i) = C_contvalue(l_max, mu_hat, sigma, sigma_star, a, dt, fwdDF_present(:,i), value(:,i+1), D_x, x);

        elseif j == 2*l_max+1
            value(j,i) = B_contvalue(l_min, mu_hat, sigma, sigma_star, a, dt, fwdDF_present(:,i), value(:,i+1), D_x, x);

        else
            value(j,i) = A_contvalue(j, mu_hat, sigma, sigma_star, a, dt, fwdDF_present(:,i), value(:,i+1), D_x, x);            
        end

    end
    
    if find(reset_dates == node_dates(i))

        % find the index of the reset date
        index = find(reset_dates == node_dates(i));

        continuation_value = max(intr_value(:,index), value(:,i));

        value(:,i) = continuation_value;
    
    else
        continue
    end

    
    %value(:,i) = continuation_value;
   
end
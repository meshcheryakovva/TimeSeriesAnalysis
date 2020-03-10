function showplots
  % Построение графиков моделей временных рядов.
  % Демонстрация вычисления результата сделок.
  % Для запуска в среде MATLAB.
  
  close all; clc;
   
  % считываем временные ряды
  D = readD('day.txt');
  [H, Days] = readH('hour.txt');
  
  % Частный случай решения задачи
  n = 4;  % число периодов для построения простой скользящей средней SMA D
  a = 8;  % число периодов для экспоненциальной скольящей средней EMA1
  b = 2;  % число периодов для экспоненциальной скольящей средней EMA2
  c = 29; % число периодов для экспоненциальной скольящей средней EMA3
  
  % Скользящие средние
  SMAD = sma(D, n);
  E = ema(H, a) - ema(H, b);
  EMA3 = ema(E, c);
  
  % Обработка дневных цен
  figure; plot(D, '-b.');
  hold on; grid on;
  plot(SMAD, '-r.');
  xlabel('дни'), ylabel('D')
  legend('D', 'SMA')
  
  % Ограничение на сделки
  % покупка (флаг Buy), если сегодня и вчера D выше сигнальной линии
  Dprev = [1; D(1:end-1)];     
  SMADprev = [0; SMAD(1:end-1)];
  Buy = (D > SMAD) & (Dprev > SMADprev); % логич 1, если покупка, 0 - иначе
  % продажа (флаг Sale), если сегодня и вчера D ниже сигнальной линии
  Dprev(1) = -1;     
  Sale = (D < SMAD) & (Dprev < SMADprev); % логич 1, если продажа, 0 - иначе

  % Обработка часовых цен
  figure; plot(H); hold on; grid on
  plot(Days, D, '*')
  plot(ema(H, a), 'm'); plot(ema(H, b), 'k');
  plot(E, 'g'); plot(EMA3, 'r');
  xlabel('часы'), ylabel('H')
  legend('Н', 'D', 'EMA1','EMA2','EMA1-EMA2', 'EMA3')
  
  Profit = 0; % сумма всех сделок
  LH = length(H);  % количество часов (всего)
  CurrentDay = 1; % текущий день
  
  % флаги открытия сделок
  BuyOpened = false;  % продажи
  SaleOpened = false; % покупки
  
  for CurrentHour = 1:LH, % цикл обработки данных по часам
    % определяем текущий день
    if CurrentHour > Days(CurrentDay), CurrentDay = CurrentDay + 1;  end
    
    % открыта сделка покупки,
    % и E пересекла сигнальную линию
    if BuyOpened && (E(CurrentHour) < EMA3(CurrentHour)),
      BuyOpened = false; % закрываем сделку покупки
      BuyClosePrice = H(CurrentHour); % цена на момент закрытия

      disp('сделка покупки закрыта, час')
      disp(CurrentHour);
      Profit = Profit + BuyClosePrice - BuyOpenPrice
    end
    
    % если сегодня возможны только покупки,
    % нет открытых сделок,
    % и E превысило сигнальную линию
    if Buy(CurrentDay) && ~BuyOpened && ~SaleOpened &&  ...
       (E(CurrentHour) > EMA3(CurrentHour)), 
      BuyOpened = true; % выставляем флаг открытой покупки
      BuyOpenPrice = H(CurrentHour); % цена на момент открытия
      disp('сделка покупки открыта, час')
      disp(CurrentHour);
    end
    
    % открыта сделка продажи,
    % и E пересекла сигнальную линию
    if SaleOpened && (E(CurrentHour) > EMA3(CurrentHour)),
      SaleOpened = false; % закрываем сделку продажи
      SaleClosePrice = H(CurrentHour); % цена на момент закрытия
      disp('сделка продажи закрыта, час')
      disp(CurrentHour);
      Profit = Profit + SaleOpenPrice - SaleClosePrice
    end
    
    % если сегодня возможны только продажи,
    % нет открытых сделок,
    % и E стала ниже сигнальной линии
    if Sale(CurrentDay) && ~BuyOpened && ~SaleOpened &&  ...
       (E(CurrentHour) < EMA3(CurrentHour)), 
      SaleOpened = true; % выставляем флаг открытой покупки
      SaleOpenPrice = H(CurrentHour); % цена на момент открытия
      disp('сделка продажи открыта, час')
      disp(CurrentHour);
    end
  end
end


% Считывание данных из файла дневных цен
% rD - массив дневных цен
% DFileName - строка, содержащая путь к файлу
function rD = readD(DFileName)
  fid = fopen(DFileName);
  C = textscan(fid, '%s %f', 'Delimiter', ';');
  fclose(fid);
  rD = C{:,2};
end

% Считывание данных из файла часовых цен
% rH - массив часовых цен
% rDays - номера элементов в массиве, соответстующие дневным ценам
% HFileName - строка, содержащая путь к файлу
function [rH, rDays] = readH(HFileName)
  fid = fopen(HFileName);
  C = textscan(fid, '%f-%f-%f %f:%f:%f;%f');
  fclose(fid);
  
  rH = C{:,7}; % часовые цены
 
  % номера в массиве часов, соответстующие дневным ценам
  rDates = C{:,3}; % даты (числа месяца)
  difDates = diff(rDates); % разница дат
  rDaystemp = find(difDates ~= 0); % ищем моменты смены дат
  rDays = [rDaystemp; length(rDates)];
end

% вычисление простой скольящей средней по n периодам
function y = sma(x, n)
  a = 1;               % знаменатель ПФ фильтра
  b = ones(1, n) ./ n; % числитель ПФ фильтра
  y = filter(b, a, x);
  y(1:(n-1)) = x(1:(n-1)); % несглаженный участок в начале
end

% вычисление экспоненциальной скольящей средней по n периодам
function y = ema(x, n)
  alpha =  2 / (n+1);  % параметр сглаживания
  a = [1 (alpha-1)];   % знаменатель ПФ фильтра
  b = alpha;           % числитель ПФ фильтра
  zi = x(1)*(1-alpha); % начальные условия
  y = filter(b, a, x, zi);
end
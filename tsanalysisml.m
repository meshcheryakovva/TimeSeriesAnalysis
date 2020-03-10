function tsanalysisml
  % Функция поиска оптимальных параметров моделей временных рядов
  % на основе генетического алгоритма.
  % Решение задачи целочисленного программирования.
  % Версия для запуска под MATLAB.
  
  % считываем временные ряды
  D = readD('day.txt');
  [H, Days] = readH('hour.txt');
    
  % Постановка задачи оптимизации
  % n - число периодов для построения простой скользящей средней SMA D
  % a - число периодов для экспоненциальной скольящей средней EMA1
  % b - число периодов для экспоненциальной скольящей средней EMA2
  % c - число периодов для экспоненциальной скольящей средней EMA3
  % X = [a; b; c; n] вектор переменных (особь)
  
  % граничные условия
  lb = [2; 2; 2; 2]; % нижняя граница X
  abcub = length(H)-1;
  ub = [abcub; abcub; abcub; (length(D)-1)]; % верхняя граница X

  % Настройки параметров генетического алгоритма оптимизации
  options = gaoptimset(@ga); % структура параметров
  options.Display = 'iter';  % вывод результатов
 % options.Display = 'off';  % вывод результатов
  options.PopulationSize = 25; % размер популяции (количество решений X на каждом шаге оптимизации)
  options.PopInitRange = [1; 50]; % начальный диапазон переменных
  options.TolFun = 1e-12; % сходимость при вычислении целевой функции
  options.TolCon = 1e-12; % сходимость при вычислении ограничений 
  options.Generations = 500; % число шагов алгоритма (поколений)
  options.CrossoverFraction = 0.6; % доля особей в поколении, полученных путем скрещивания
  options.MigrationFraction = 0.6; % доля особей, участвующих в обмене между группами
  options.EliteCount = 6; % количество элитных особей, переходящих в новое поколение
  
  % вызов солвера
  [x, fval] = ga(@GoalFun, 4, [], [], [], [], lb, ub, [], [1;2;3;4], options);

  fmax = -fval; % поскольку решается задача на максимум
  % Вывод оптимального решения
  disp('a = '), disp(x(1)),
  disp('b = '), disp(x(2)),
  disp('c = '), disp(x(3)),
  disp('n = '), disp(x(4)),
  disp('Результат сделок'), disp(fmax)

  % сохраняем результат в текстовый файл
  % структура файла:
  % a b c n Суммарный_результат_сделок
  save abcn_f.txt x fmax -ascii
 
  
  
  % Проверка - решение задачи перебором
  %{
  
  Fmax = 0;
  for n1 = 2:20,
    for c1 = 2:20,
        disp((c1-2)*400)
        for b1 = 2:20;
            for a1 = 2:20,
                x1 = [a1, b1, c1, n1];
                F = -GoalFun(x1); % вызов целевой функции
                if F > Fmax,
                    Fmax = F;
                    xopt = x1;
                    save combinat.txt xopt Fmax -ascii;
                end
            end
        end
    end
  end
  
  %}
  
  function Profit = GoalFun(x)
  % вложенная функция, вычисляющая суммарный результат сделок (с обратным знаком)
      a = x(1);
      b = x(2);
      c = x(3);
      n = x(4);
      
      % ограничение
      if a == b, Profit = 0; return, end
      
      % Скользящие средние
      SMAD = sma(D, n);
      E = ema(H, a) - ema(H, b);
      EMA3 = ema(E, c);

      % Обработка дневных цен
      % Ограничение на сделки
      % покупка, если сегодня и вчера D выше сигнальной линии
      Dprev = [1; D(1:end-1)];     
      SMADprev = [0; SMAD(1:end-1)];
      Buy = (D > SMAD) & (Dprev > SMADprev); % логич 1, если покупка, 0 - иначе
      % продажа, если сегодня и вчера D ниже сигнальной линии
      Dprev(1) = -1;     
      Sale = (D < SMAD) & (Dprev < SMADprev); % логич 1, если продажа, 0 - иначе

      % Обработка часовых цен
      Profit = 0; % сумма всех сделок
      LH = length(H);  % количество часов (всего)
      CurrentDay = 1; % текущий день

      % флаги открытия сделок
      BuyOpened  = false; % продажи
      SaleOpened = false; % покупки

      for CurrentHour = 1:LH, % цикл обработки данных по часам
        % определяем текущий день
        if CurrentHour > Days(CurrentDay), CurrentDay = CurrentDay + 1;  end

        % открыта сделка покупки, и E пересекла сигнальную линию
        if BuyOpened && (E(CurrentHour) < EMA3(CurrentHour)),
          BuyOpened = false; % закрываем сделку покупки
          BuyClosePrice = H(CurrentHour); % цена на момент закрытия
          Profit = Profit + BuyClosePrice - BuyOpenPrice;
        end

        % если сегодня возможны только покупки,
        % нет открытых сделок, и E превысило сигнальную линию
        if Buy(CurrentDay) && ~BuyOpened && ~SaleOpened &&  ...
              (E(CurrentHour) > EMA3(CurrentHour)), 
          BuyOpened = true; % выставляем флаг открытой покупки
          BuyOpenPrice = H(CurrentHour); % цена на момент открытия
        end

        % открыта сделка продажи, и E пересекла сигнальную линию
        if SaleOpened && (E(CurrentHour) > EMA3(CurrentHour)),
          SaleOpened = false; % закрываем сделку продажи
          SaleClosePrice = H(CurrentHour); % цена на момент закрытия
          Profit = Profit + SaleOpenPrice - SaleClosePrice;
        end

        % если сегодня возможны только продажи,
        % нет открытых сделок, и E стала ниже сигнальной линии
        if Sale(CurrentDay) && ~BuyOpened && ~SaleOpened &&  ...
               (E(CurrentHour) < EMA3(CurrentHour)), 
          SaleOpened = true; % выставляем флаг открытой покупки
          SaleOpenPrice = H(CurrentHour); % цена на момент открытия
        end
      end
      Profit = -Profit; % для минимизации функции подгонки
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
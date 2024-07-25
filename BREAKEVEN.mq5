//|                                                    BREAKEVEN.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

// Include necessary libraries
#include <Controls\Panel.mqh>
#include <Controls\Label.mqh>

#include <Trade/Trade.mqh>
CTrade trade;
// Define panel and control objects
CPanel P1;
CLabel LabelTitle, LabelBalance, LabelEquity, LabelProfit, LabelDrawdown;

input double FixLotSize = 0.1; // Fixed lot size
input int StopLoss = 100; // Stop loss in pips
input bool UseStopLoss = true; // Use stop loss
input int TakeProfit = 300; // Take profit in pips
input bool UseTakeProfit = true; // Use take profit
input bool UseAutomaticLotSize = false; // Use automatic lot size
input double RiskPercentage = 1.0; // Risk percentage

// Input parameters
input bool BreakevenMode = true;
input double BreakEven_After_Pts = 50;
input double BreakEven_At_Pts = 50;

input bool TrailingMode = true;
input int Trail_Stop = 100;
input int Trail_Step = 50;
input int Trail_Gap = 50;




input ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT; // Time frame input



input double GMTOffset = 7.0; // Offset in hours
input double TokyoStartTime = 7.0; // Tokyo start time in hours
input double TokyoEndTime = 10.0; // Tokyo end time in hours
input double LondonStartTime = 13.0; // London start time in hours
input double LondonEndTime = 16.0; // London end time in hours
input double USStartTime = 19.0; // US start time in hours
input double USEndTime = 22.0; // US end time in hours




//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    
    
   // Create the panel
   if (!Panel())
   {
      Print("Failed to create panel");
      return(INIT_FAILED);
   }

   // Get the current chart ID
   long chart_id = ChartID();

   // Set the colors for the chart candles
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BULL, clrMediumBlue); // Up candle color
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BEAR, clrGray);       // Down candle color
   ChartSetInteger(chart_id, CHART_COLOR_CHART_UP, clrMediumBlue);    // Bar Up color
   ChartSetInteger(chart_id, CHART_COLOR_CHART_DOWN, clrGray);        // Bar Down color

   // Set the background color to black
   ChartSetInteger(chart_id, CHART_COLOR_BACKGROUND, clrBlack);       // Background color

   // Set the foreground color to light cyan
   ChartSetInteger(chart_id, CHART_COLOR_FOREGROUND, clrLightCyan);   // Foreground color

   // Disable the grid
   ChartSetInteger(chart_id, CHART_SHOW_GRID, false);                 // Disable grid

   EventSetTimer(1); // Set a timer to update the panel every second

    //---
    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
// Cleanup code here
   EventKillTimer(); // Kill the timer
   P1.Destroy();    // Delete the panel when the EA is removed
   LabelTitle.Destroy();
   LabelBalance.Destroy();
   LabelEquity.Destroy();
   LabelProfit.Destroy();
   LabelDrawdown.Destroy();
    //---
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() 
{
    // Check time settings
    if (!IsTradingTime()) {
        
        return;
    }

    // Check if there are any open positions
    if (PositionsTotal() > 0) {
        // Loop through all open positions
        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);

            // Apply BreakEven if enabled
            if (BreakevenMode) {
                breakEven(ticket, BreakEven_After_Pts, BreakEven_At_Pts);
            }

            // Apply TrailingStop if enabled
            if (TrailingMode) {
                trailingStop(ticket, Trail_Stop, Trail_Step, Trail_Gap);
            }
        }
        return; // Exit if there are existing positions
    }

    double lotSize = CalculateLotSize();  // Declare lotSize here
    // Identify candlestick patterns
   
    // Identify trends based on EMA crossovers
    int trend = IdentifyTrend();
   
    // Identify candlestick patterns and place orders based on the trend
    if (CheckDoji()) 
    {
        PlaceOrder(Symbol(), trend == 1, lotSize, StopLoss, TakeProfit); // Buy if uptrend, Sell if downtrend
    }
    else if (CheckHammer()) 
    {
        PlaceOrder(Symbol(), true, lotSize, StopLoss, TakeProfit); // Always Buy
    }
    else if (CheckShootingStar()) 
    {
        PlaceOrder(Symbol(), false, lotSize, StopLoss, TakeProfit); // Always Sell
    }
    else if (CheckSpinningTop()) 
    {
        PlaceOrder(Symbol(), trend == 1, lotSize, StopLoss, TakeProfit); // Buy if uptrend, Sell if downtrend
    }
    else if (CheckBullishEngulfing()) 
    {
        PlaceOrder(Symbol(), true, lotSize, StopLoss, TakeProfit); // Always Buy
    }
    else if (CheckBearishEngulfing()) 
    {
        PlaceOrder(Symbol(), false, lotSize, StopLoss, TakeProfit); // Always Sell
    }
    else if (CheckTweezerTopsBottoms()) 
    {
        PlaceOrder(Symbol(), trend == 1, lotSize, StopLoss, TakeProfit); // Buy if uptrend, Sell if downtrend
    }
    else if (CheckMorningStar()) 
    {
        PlaceOrder(Symbol(), true, lotSize, StopLoss, TakeProfit); // Always Buy
    }
    else if (CheckEveningStar()) 
    {
        PlaceOrder(Symbol(), false, lotSize, StopLoss, TakeProfit); // Always Sell
    }
    else if (CheckThreeWhiteSoldiers()) 
    {
        PlaceOrder(Symbol(), true, lotSize, StopLoss, TakeProfit); // Always Buy
    }
    else if (CheckThreeBlackCrows()) 
    {
        PlaceOrder(Symbol(), false, lotSize, StopLoss, TakeProfit); // Always Sell
    }
}

//+------------------------------------------------------------------+
// BreakEven function
void breakEven(ulong ticket, double breakEvenAfterPts, double breakEvenAtPts) {
    double price = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double stopLoss = PositionGetDouble(POSITION_SL);
    double profit = PositionGetDouble(POSITION_PROFIT);

    // Calculate the profit in points
    double profitInPoints = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                             (currentPrice - price) / Point() :
                             (price - currentPrice) / Point();

    Print("Profit in Points: ", profitInPoints, " | Required: ", breakEvenAfterPts);
    Print("Current Stop Loss: ", stopLoss);

    // Check if the order is profitable and has reached the break-even level
    if (profitInPoints >= breakEvenAfterPts) {
        // Move the stop loss to the entry price plus buffer
        if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            double newStopLoss = price + breakEvenAtPts * Point();
            Print("New Stop Loss for BUY: ", newStopLoss);
            if (newStopLoss > stopLoss) {
                bool modified = trade.PositionModify(ticket, newStopLoss, PositionGetDouble(POSITION_TP));
                if (modified) {
                    Print("BUY position stop loss modified to: ", newStopLoss);
                } else {
                    Print("Error modifying BUY position stop loss: ", trade.ResultRetcode());
                }
            }
        } else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
            double newStopLoss = price - breakEvenAtPts * Point();
            Print("New Stop Loss for SELL: ", newStopLoss);
            if (newStopLoss < stopLoss || stopLoss == 0) { // Also check if stopLoss is not set yet
                bool modified = trade.PositionModify(ticket, newStopLoss, PositionGetDouble(POSITION_TP));
                if (modified) {
                    Print("SELL position stop loss modified to: ", newStopLoss);
                } else {
                    Print("Error modifying SELL position stop loss: ", trade.ResultRetcode());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
// TrailingStop function
void trailingStop(ulong ticket, double trailStop, double trailStep, double trailGap) {
    double price = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double stopLoss = PositionGetDouble(POSITION_SL);

    // Calculate new stop loss
    double newStopLoss;
    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
        newStopLoss = currentPrice - trailStop * Point();
        if (newStopLoss > stopLoss && newStopLoss > price + trailGap * Point()) { // Ensure trailing stop only moves forward
            trade.PositionModify(ticket, newStopLoss, PositionGetDouble(POSITION_TP));
        }
    } else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
        newStopLoss = currentPrice + trailStop * Point();
        if (newStopLoss < stopLoss && newStopLoss < price - trailGap * Point()) { // Ensure trailing stop only moves forward
            trade.PositionModify(ticket, newStopLoss, PositionGetDouble(POSITION_TP));
        }
    }
}

//+------------------------------------------------------------------+
//| Identify Trend                                                   |
//+------------------------------------------------------------------+
int IdentifyTrend()
{
    double ema86_prev = iMA(Symbol(), TimeFrame, 86, 0, MODE_EMA, PRICE_CLOSE);
    double ema50_prev = iMA(Symbol(), TimeFrame, 50, 0, MODE_EMA, PRICE_CLOSE);
    double ema25_prev = iMA(Symbol(), TimeFrame, 25, 0, MODE_EMA, PRICE_CLOSE);
    double ema86_curr = iMA(Symbol(), TimeFrame, 86, 0, MODE_EMA, PRICE_CLOSE);
    double ema50_curr = iMA(Symbol(), TimeFrame, 50, 0, MODE_EMA, PRICE_CLOSE);
    double ema25_curr = iMA(Symbol(), TimeFrame, 25, 0, MODE_EMA, PRICE_CLOSE);

    if (ema25_prev > ema50_prev && ema25_curr < ema50_curr && ema50_prev > ema86_prev && ema50_curr < ema86_curr) // Slup kun
    {
        return 1; // Uptrend
    }
    else if (ema25_prev < ema50_prev && ema25_curr > ema50_curr && ema50_prev < ema86_prev && ema50_curr > ema86_curr)
    {
        return -1; // Downtrend
    }
    return 0; // No clear trend
}

//+------------------------------------------------------------------+
//| Identify Doji pattern                                            |
//+------------------------------------------------------------------+
bool CheckDoji()
{
    double open = iOpen(Symbol(), TimeFrame, 0);
    double close = iClose(Symbol(), TimeFrame, 0);
    double high = iHigh(Symbol(), TimeFrame, 0);
    double low = iLow(Symbol(), TimeFrame, 0);
    double body = MathAbs(close - open);
    double range = high - low;

    if (body < (0.1 * range)) 
    {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Identify Hammer pattern                                          |
//+------------------------------------------------------------------+
bool CheckHammer()
{
    double open = iOpen(Symbol(), TimeFrame, 0);
    double close = iClose(Symbol(), TimeFrame, 0);
    double high = iHigh(Symbol(), TimeFrame, 0);
    double low = iLow(Symbol(), TimeFrame, 0);
    double body = MathAbs(close - open);
    double lower_wick = open < close ? open - low : close - low;
    double upper_wick = high - (open > close ? open : close);

    if (body < (0.3 * lower_wick) && lower_wick > (2 * body) && upper_wick < (0.1 * body))
    {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Identify Shooting Star pattern                                   |
//+------------------------------------------------------------------+
bool CheckShootingStar()
{
    double open = iOpen(Symbol(), TimeFrame, 0);
    double close = iClose(Symbol(), TimeFrame, 0);
    double high = iHigh(Symbol(), TimeFrame, 0);
    double low = iLow(Symbol(), TimeFrame, 0);
    double body = MathAbs(close - open);
    double upper_wick = high - (open > close ? open : close);
    double lower_wick = open < close ? open - low : close - low;

    if (body < (0.3 * upper_wick) && upper_wick > (2 * body) && lower_wick < (0.1 * body))
    {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Identify Spinning Top pattern                                    |
//+------------------------------------------------------------------+
bool CheckSpinningTop()
{
    double open = iOpen(Symbol(), TimeFrame, 0);
    double close = iClose(Symbol(), TimeFrame, 0);
    double high = iHigh(Symbol(), TimeFrame, 0);
    double low = iLow(Symbol(), TimeFrame, 0);
    double body = MathAbs(close - open);
    double upper_wick = high - (open > close ? open : close);
    double lower_wick = open < close ? open - low : close - low;
    double range = high - low;

    if (body < (0.3 * range) && upper_wick > (0.3 * range) && lower_wick > (0.3 * range))
    {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Identify Bullish Engulfing pattern                               |
//+------------------------------------------------------------------+
bool CheckBullishEngulfing()
{
    double open1 = iOpen(Symbol(), TimeFrame, 1);
    double close1 = iClose(Symbol(), TimeFrame, 1);
    double open2 = iOpen(Symbol(), TimeFrame, 0);
    double close2 = iClose(Symbol(), TimeFrame, 0);

    if (close1 < open1 && close2 > open2 && open2 < close1 && close2 > open1)
    {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Identify Bearish Engulfing pattern                               |
//+------------------------------------------------------------------+
bool CheckBearishEngulfing()
{
    double open1 = iOpen(Symbol(), TimeFrame, 1);
    double close1 = iClose(Symbol(), TimeFrame, 1);
    double open2 = iOpen(Symbol(), TimeFrame, 0);
    double close2 = iClose(Symbol(), TimeFrame, 0);

    if (close1 > open1 && close2 < open2 && open2 > close1 && close2 < open1)
    {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Identify Tweezer Tops and Bottoms pattern                        |
//+------------------------------------------------------------------+
bool CheckTweezerTopsBottoms()
{
    double high1 = iHigh(Symbol(), TimeFrame, 1);
    double low1 = iLow(Symbol(), TimeFrame, 1);
    double high2 = iHigh(Symbol(), TimeFrame, 0);
    double low2 = iLow(Symbol(), TimeFrame, 0);

    if (high1 == high2 || low1 == low2)
    {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Identify Morning Star pattern                                    |
//+------------------------------------------------------------------+
bool CheckMorningStar()
{
    double open1 = iOpen(Symbol(), TimeFrame, 2);
    double close1 = iClose(Symbol(), TimeFrame, 2);
    double open2 = iOpen(Symbol(), TimeFrame, 1);
    double close2 = iClose(Symbol(), TimeFrame, 1);
    double open3 = iOpen(Symbol(), TimeFrame, 0);
    double close3 = iClose(Symbol(), TimeFrame, 0);

    if (close1 < open1 && close2 < open2 && close2 > open3 && close3 > open3)
    {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Identify Evening Star pattern                                    |
//+------------------------------------------------------------------+
bool CheckEveningStar()
{
    double open1 = iOpen(Symbol(), TimeFrame, 2);
    double close1 = iClose(Symbol(), TimeFrame, 2);
    double open2 = iOpen(Symbol(), TimeFrame, 1);
    double close2 = iClose(Symbol(), TimeFrame, 1);
    double open3 = iOpen(Symbol(), TimeFrame, 0);
    double close3 = iClose(Symbol(), TimeFrame, 0);

    if (close1 > open1 && close2 < open2 && close2 < open3 && close3 < open3)
    {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Identify Three White Soldiers pattern                            |
//+------------------------------------------------------------------+
bool CheckThreeWhiteSoldiers()
{
    double open1 = iOpen(Symbol(), TimeFrame, 2);
    double close1 = iClose(Symbol(), TimeFrame, 2);
    double open2 = iOpen(Symbol(), TimeFrame, 1);
    double close2 = iClose(Symbol(), TimeFrame, 1);
    double open3 = iOpen(Symbol(), TimeFrame, 0);
    double close3 = iClose(Symbol(), TimeFrame, 0);

    if (close1 > open1 && close2 > open2 && close3 > open3 && close2 > close1 && close3 > close2)
    {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Identify Three Black Crows pattern                               |
//+------------------------------------------------------------------+
bool CheckThreeBlackCrows()
{
    double open1 = iOpen(Symbol(), TimeFrame, 2);
    double close1 = iClose(Symbol(), TimeFrame, 2);
    double open2 = iOpen(Symbol(), TimeFrame, 1);
    double close2 = iClose(Symbol(), TimeFrame, 1);
    double open3 = iOpen(Symbol(), TimeFrame, 0);
    double close3 = iClose(Symbol(), TimeFrame, 0);

    if (close1 < open1 && close2 < open2 && close3 < open3 && close2 < close1 && close3 < close2)
    {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Place Order                                                      |
//+------------------------------------------------------------------+
void PlaceOrder(string symbol, bool isBuy, double lotSize, double stopLoss, double takeProfit)
{
    double price = (isBuy) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl = (isBuy && UseStopLoss) ? price - stopLoss * _Point : 0;
    double tp = (isBuy && UseTakeProfit) ? price + takeProfit * _Point : 0;
    if (!isBuy && UseStopLoss) sl = price + stopLoss * _Point;
    if (!isBuy && UseTakeProfit) tp = price - takeProfit * _Point;

    bool result;
    if (isBuy)
    {
        result = trade.Buy(lotSize, symbol, price, sl, tp, "");
    }
    else
    {
        result = trade.Sell(lotSize, symbol, price, sl, tp, "");
    }

    if (!result)
    {
        Print("Error opening order: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    if (UseAutomaticLotSize)
    {
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = accountBalance * (RiskPercentage / 100.0);
        double pipValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
        double stopLossInPips = StopLoss;
        double lot = riskAmount / (stopLossInPips * pipValue);
        return NormalizeDouble(lot, 2);
    }
    return FixLotSize;
}
//+------------------------------------------------------------------+
//| Check if it's trading time                                       |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
    datetime time = TimeCurrent();
    datetime localTime = time + (int)(GMTOffset * 3600);

    MqlDateTime structLocalTime;
    TimeToStruct(localTime, structLocalTime);

    double localTimeInHours = structLocalTime.hour + (structLocalTime.min / 60.0);

    if ((localTimeInHours >= TokyoStartTime && localTimeInHours <= TokyoEndTime) ||
        (localTimeInHours >= LondonStartTime && localTimeInHours <= LondonEndTime) ||
        (localTimeInHours >= USStartTime && localTimeInHours <= USEndTime))
    {
        return true;
    }

    return false;
}


//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Update the panel with dynamic data
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double profit = (equity - balance) / balance * 100; // Profit percentage
   double drawdown = AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_EQUITY);

   LabelBalance.Text("Balance: " + DoubleToString(balance, 2));
   LabelEquity.Text("Equity: " + DoubleToString(equity, 2));
   LabelProfit.Text("Profit (percentage): " + DoubleToString(profit, 2) + "%");
   LabelDrawdown.Text("Drawdown: " + DoubleToString(drawdown, 2));
}


//+------------------------------------------------------------------+
//| Create the panel and controls                                    |
//+------------------------------------------------------------------+
bool Panel()
{
   // Get the current chart width and height
   int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);

   // Define panel dimensions
   int panel_width = 400;
   int panel_height = 250;

   // Calculate the x-coordinate for the panel to be aligned to the right side
   int x = 20; // 10-pixel margin from the right edge
   int y = 20; // 100-pixel offset from the top

   // Create the panel
   if (!P1.Create(0, "P1", 0, x, y, panel_width, panel_height))
   {
      Print("Failed to create panel");
      return(false);
   }
   P1.ColorBackground(clrMidnightBlue); // Set the background color of the panel
   P1.ColorBorder(clrGold); // Set the border color of the panel to gold

   // Create and position the title label
   LabelTitle.Create(0, "LabelTitle", 0, x + 105, y + 10, x + 380, y + 30);
   LabelTitle.Text("King Of Candle");
   LabelTitle.ColorBackground(clrNONE);
   LabelTitle.Color(clrGold);
   LabelTitle.FontSize(20);

   // Create and position the balance label
   LabelBalance.Create(0, "LabelBalance", 0, x + 10, y + 60, x + 380, y + 120);
   LabelBalance.Text("Balance: ");
   LabelBalance.ColorBackground(clrNONE);
   LabelBalance.Color(clrWhiteSmoke);
   LabelBalance.FontSize(15);

   // Create and position the equity label
   LabelEquity.Create(0, "LabelEquity", 0, x + 10, y + 100, x + 380, y + 160);
   LabelEquity.Text("Equity: ");
   LabelEquity.ColorBackground(clrNONE);
   LabelEquity.Color(clrYellow);
   LabelEquity.FontSize(15);

   // Create and position the profit label
   LabelProfit.Create(0, "LabelProfit", 0, x + 10, y + 140, x + 380, y + 200);
   LabelProfit.Text("Profit (percentage): ");
   LabelProfit.ColorBackground(clrNONE);
   LabelProfit.Color(clrGreenYellow);
   LabelProfit.FontSize(15);

   // Create and position the drawdown label
   LabelDrawdown.Create(0, "LabelDrawdown", 0, x + 10, y + 180, x + 380, y + 250);
   LabelDrawdown.Text("Drawdown: ");
   LabelDrawdown.ColorBackground(clrNONE);
   LabelDrawdown.Color(clrRed);
   LabelDrawdown.FontSize(15);

   return(true); // Ensure the function returns true if the panel is created successfully
}

//+------------------------------------------------------------------+
//|                                                 OB_Probe_MT5.mq5 |
//|                                                                  |
//|  Answers one question: does the MT5 Order Block indicator publish |
//|  its blocks as BUFFERS, or only as drawings on the chart?         |
//|                                                                  |
//|  It matters because an EA can read buffers during optimisation,   |
//|  but drawings do not exist there - no chart, nothing to read.     |
//|                                                                  |
//|  Read only. It never creates, moves or deletes anything, and it   |
//|  never trades.                                                    |
//+------------------------------------------------------------------+
#property copyright "Anirudha Talmale"
#property version   "1.00"
#property script_show_inputs

input string IndicatorName = "OB + Void MT5 By TFlab"; // Exact file name, no .ex5
input int    BuffersToTest = 24;                       // How many buffer slots to try
input int    BarsToTest    = 5;                        // Values to read per buffer

//+------------------------------------------------------------------+
void W(const int h, const string s)
  {
   FileWrite(h, s);
   Print(s);
  }
//+------------------------------------------------------------------+
string ObjTypeName(const long t)
  {
   switch((ENUM_OBJECT)t)
     {
      case OBJ_RECTANGLE: return("OBJ_RECTANGLE");
      case OBJ_TREND:     return("OBJ_TREND");
      case OBJ_HLINE:     return("OBJ_HLINE");
      case OBJ_VLINE:     return("OBJ_VLINE");
      case OBJ_TEXT:      return("OBJ_TEXT");
      case OBJ_LABEL:     return("OBJ_LABEL");
      case OBJ_ARROW:     return("OBJ_ARROW");
     }
   return("OTHER("+IntegerToString(t)+")");
  }
//+------------------------------------------------------------------+
void OnStart()
  {
   string fname = "OB_Probe_MT5_" + _Symbol + "_" + IntegerToString(PeriodSeconds()/60) + ".txt";
   int h = FileOpen(fname, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h == INVALID_HANDLE)
     {
      Alert("Cannot create the file. Error ", GetLastError());
      return;
     }

   W(h, "=================================================");
   W(h, "  OB PROBE - MT5");
   W(h, "=================================================");
   W(h, "Symbol    : " + _Symbol);
   W(h, "Period    : " + EnumToString(_Period));
   W(h, "Digits    : " + IntegerToString(_Digits));
   W(h, "Bid       : " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits));
   W(h, "Indicator : " + IndicatorName);
   W(h, "");

//---- THE QUESTION: does it expose buffers?
   W(h, "--- BUFFER TEST (this is the one that matters) ---");
   ResetLastError();
   int ih = iCustom(_Symbol, PERIOD_CURRENT, IndicatorName);
   if(ih == INVALID_HANDLE)
     {
      W(h, "iCustom FAILED, error " + IntegerToString(GetLastError()));
      W(h, "The indicator was not found. Check the name and that it sits directly");
      W(h, "in MQL5\\Indicators\\ (if it is in a subfolder, use Subfolder\\\\Name).");
     }
   else
     {
      W(h, "iCustom handle obtained.");
      //---- give it a moment to calculate
      int calculated = 0;
      for(int wait = 0; wait < 50; wait++)
        {
         calculated = BarsCalculated(ih);
         if(calculated > 0) break;
         Sleep(100);
        }
      W(h, "BarsCalculated: " + IntegerToString(calculated));
      W(h, "");

      int withData = 0;
      for(int b = 0; b < BuffersToTest; b++)
        {
         double buf[];
         ArraySetAsSeries(buf, true);
         ResetLastError();
         int got = CopyBuffer(ih, b, 0, BarsToTest, buf);
         if(got <= 0)
           {
            W(h, "buffer " + IntegerToString(b) + " : not available (CopyBuffer returned "
                 + IntegerToString(got) + ", error " + IntegerToString(GetLastError()) + ")");
            continue;
           }
         string line = "buffer " + IntegerToString(b) + " : ";
         bool anyReal = false;
         for(int k = 0; k < got; k++)
           {
            if(buf[k] == EMPTY_VALUE)      line += "EMPTY  ";
            else
              {
               line += DoubleToString(buf[k], _Digits) + "  ";
               if(buf[k] != 0.0) anyReal = true;
              }
           }
         if(anyReal) withData++;
         W(h, line + (anyReal ? "   <-- HAS REAL VALUES" : ""));
        }
      W(h, "");
      W(h, "Buffers carrying real values: " + IntegerToString(withData));
      W(h, withData > 0
            ? ">>> GOOD: the indicator publishes data through buffers."
            : ">>> The indicator publishes nothing through buffers.");
      IndicatorRelease(ih);
     }

//---- and what it draws, for comparison with the MT4 capture
   int total = ObjectsTotal(0, -1, -1);
   W(h, "");
   W(h, "--- CHART OBJECTS: " + IntegerToString(total) + " ---");
   W(h, "idx | name | type | price1 | price2 | time1 | colour | text");
   for(int i = 0; i < total; i++)
     {
      string nm = ObjectName(0, i, -1, -1);
      W(h, IntegerToString(i) + " | " + nm + " | "
           + ObjTypeName(ObjectGetInteger(0, nm, OBJPROP_TYPE)) + " | "
           + DoubleToString(ObjectGetDouble(0, nm, OBJPROP_PRICE, 0), _Digits) + " | "
           + DoubleToString(ObjectGetDouble(0, nm, OBJPROP_PRICE, 1), _Digits) + " | "
           + TimeToString((datetime)ObjectGetInteger(0, nm, OBJPROP_TIME, 0)) + " | "
           + IntegerToString(ObjectGetInteger(0, nm, OBJPROP_COLOR)) + " | "
           + ObjectGetString(0, nm, OBJPROP_TEXT));
     }

   W(h, "");
   W(h, "--- end ---");
   FileClose(h);
   Alert("OB_Probe_MT5 finished. File: MQL5\\Files\\" + fname);
  }
//+------------------------------------------------------------------+

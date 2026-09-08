//+------------------------------------------------------------------+
//|                                                     OB_Probe.mq4 |
//|                                                                  |
//|  Diagnostic script. Dumps every object drawn on the current      |
//|  chart to a text file, and probes the indicator for iCustom      |
//|  buffers. Used to discover exactly how the Order Blocks          |
//|  indicator publishes its zones, so the EA can read them.         |
//|                                                                  |
//|  It only reads. It never creates, moves, deletes or trades.      |
//+------------------------------------------------------------------+
#property copyright "Anirudha Talmale"
#property version   "1.00"
#property strict
#property show_inputs

input string IndicatorName  = "Order Block + Void MT4 By TFlab"; // Indicator file name, no .ex4
input bool   ProbeBuffers   = true;                     // Also probe iCustom buffers
input int    BuffersToTest  = 8;                        // How many buffers to try
input int    BarsToTest     = 5;                        // Bars to read per buffer

//+------------------------------------------------------------------+
//| Write one line                                                   |
//+------------------------------------------------------------------+
void W(int h, string s)
  {
   FileWrite(h, s);
  }
//+------------------------------------------------------------------+
//| Readable name for an object type                                 |
//+------------------------------------------------------------------+
string ObjTypeName(int t)
  {
   switch(t)
     {
      case OBJ_RECTANGLE:       return("OBJ_RECTANGLE");
      case OBJ_RECTANGLE_LABEL: return("OBJ_RECTANGLE_LABEL");
      case OBJ_TREND:           return("OBJ_TREND");
      case OBJ_HLINE:           return("OBJ_HLINE");
      case OBJ_VLINE:           return("OBJ_VLINE");
      case OBJ_TEXT:            return("OBJ_TEXT");
      case OBJ_LABEL:           return("OBJ_LABEL");
      case OBJ_ARROW:           return("OBJ_ARROW");
      case OBJ_CHANNEL:         return("OBJ_CHANNEL");
      case OBJ_FIBO:            return("OBJ_FIBO");
      case OBJ_ELLIPSE:         return("OBJ_ELLIPSE");
      case OBJ_TRIANGLE:        return("OBJ_TRIANGLE");
     }
   return("OTHER");
  }
//+------------------------------------------------------------------+
//| Script entry point                                               |
//+------------------------------------------------------------------+
void OnStart()
  {
   string fname = "OB_Probe_" + Symbol() + "_" + IntegerToString(Period()) + ".txt";

   int h = FileOpen(fname, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h == INVALID_HANDLE)
     {
      Alert("OB_Probe: could not create the file. Error ", GetLastError());
      return;
     }

//---- context
   W(h, "=================================================");
   W(h, "  OB PROBE");
   W(h, "=================================================");
   W(h, "Generated : " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
   W(h, "Symbol    : " + Symbol());
   W(h, "Period    : " + IntegerToString(Period()) + " minutes");
   W(h, "Digits    : " + IntegerToString(Digits));
   W(h, "Point     : " + DoubleToString(Point, 8));
   W(h, "Bid       : " + DoubleToString(Bid, Digits));
   W(h, "Ask       : " + DoubleToString(Ask, Digits));
   W(h, "");

//---- every object on the chart
   int total = ObjectsTotal();
   W(h, "--- CHART OBJECTS: " + IntegerToString(total) + " ---");
   W(h, "");
   W(h, "idx | name | type | price1 | price2 | time1 | time2 | color | style | width | back | text");
   W(h, "-------------------------------------------------------------------------------");

   for(int i = 0; i < total; i++)
     {
      string nm = ObjectName(i);
      int    tp = ObjectType(nm);

      double p1 = ObjectGet(nm, OBJPROP_PRICE1);
      double p2 = ObjectGet(nm, OBJPROP_PRICE2);
      datetime t1 = (datetime)ObjectGet(nm, OBJPROP_TIME1);
      datetime t2 = (datetime)ObjectGet(nm, OBJPROP_TIME2);
      int    cl = (int)ObjectGet(nm, OBJPROP_COLOR);
      int    st = (int)ObjectGet(nm, OBJPROP_STYLE);
      int    wd = (int)ObjectGet(nm, OBJPROP_WIDTH);
      int    bk = (int)ObjectGet(nm, OBJPROP_BACK);
      string tx = ObjectDescription(nm);

      W(h, IntegerToString(i) + " | " +
           nm + " | " +
           ObjTypeName(tp) + "(" + IntegerToString(tp) + ") | " +
           DoubleToString(p1, Digits) + " | " +
           DoubleToString(p2, Digits) + " | " +
           TimeToString(t1, TIME_DATE|TIME_MINUTES) + " | " +
           TimeToString(t2, TIME_DATE|TIME_MINUTES) + " | " +
           IntegerToString(cl) + " | " +
           IntegerToString(st) + " | " +
           IntegerToString(wd) + " | " +
           IntegerToString(bk) + " | " +
           tx);
     }

//---- buffer probe
   if(ProbeBuffers)
     {
      W(h, "");
      W(h, "--- iCustom BUFFER PROBE: " + IndicatorName + " ---");
      W(h, "(default indicator inputs are used here, not yours)");
      W(h, "");

      for(int b = 0; b < BuffersToTest; b++)
        {
         string line = "buffer " + IntegerToString(b) + " : ";
         for(int bar = 0; bar < BarsToTest; bar++)
           {
            ResetLastError();
            double v = iCustom(NULL, 0, IndicatorName, b, bar);
            int err = GetLastError();
            if(err != 0)
              {
               line = line + "[error " + IntegerToString(err) + "]";
               break;
              }
            if(v == EMPTY_VALUE) line = line + "EMPTY  ";
            else                 line = line + DoubleToString(v, Digits) + "  ";
           }
         W(h, line);
        }
     }

   W(h, "");
   W(h, "--- end ---");
   FileClose(h);

   Print("OB_Probe: wrote MQL4\\Files\\", fname, "  (", total, " objects)");
   Alert("OB_Probe finished. File: MQL4\\Files\\" + fname + "   (" + IntegerToString(total) + " objects found)");
  }
//+------------------------------------------------------------------+

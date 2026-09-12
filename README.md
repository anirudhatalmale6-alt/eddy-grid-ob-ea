# Eddy Grid EA — Order Block entry logic (MT4)

Work in progress: replacing the PSAR / support-resistance entry triggers in
`EddyGridEA` with Order Block triggers, driven by the **Order Block + Void MT4 By TFlab** indicator (TradingFinder)
already running on the chart.

The client's EA source and the commercial indicator are **not** published here —
only my own code.

## OB_Probe.mq4

A read-only diagnostic script. Run it once on a chart that already has the
Order Blocks indicator attached, and it writes a report to
`MQL4\Files\OB_Probe_<symbol>_<period>.txt` containing:

* every object drawn on the chart — name, type, both prices, both times,
  colour, style, width and text label
* the result of probing `iCustom` buffers 0..7 on the indicator

That tells me exactly how the indicator publishes its zones — the object naming
convention, which colour maps to which block type (unmitigated / mitigated /
breaker, bullish / bearish), and whether any values are readable through
`iCustom`. The EA needs that to read the blocks reliably instead of guessing.

The script only reads. It never creates, moves or deletes an object, and it
never places a trade.

### How to run it

1. Copy `OB_Probe.mq4` to `MQL4\Scripts\` in your terminal's data folder
   (File → Open Data Folder).
2. Refresh the Navigator, then compile it in MetaEditor (F7).
3. Open a chart with the Order Blocks indicator attached and several blocks
   visible — ideally a mix of unmitigated, mitigated and breaker blocks.
4. Drag `OB_Probe` onto that chart. Leave the inputs as they are and click OK.
5. An alert tells you the file name. Find it under `MQL4\Files\`.

## verify_engine.py / verify_signals.py

Verification harnesses. They port the EA's order-block engine to Python and run
it against the real probe capture, because there is no MQL4 compiler here.

`verify_engine.py` rebuilds each block's consumed percentage from the NU/U
rectangle geometry and compares it with the percentage the indicator writes into
its own label — ground truth I did not produce. All 13 labelled blocks match
exactly; the only 3 without a label are exactly the 3 the code calls fully eaten.

`verify_signals.py` is the positive control: it walks price paths across the real
blocks and asserts what **must** fire, not only what must not — a rally producing
one sell from the correct block at the mid line, a sell-off producing buys from
two blocks in the right order, a block never firing twice in one cycle, recovery
suppressing counter-direction signals, and fully consumed blocks staying silent.

Neither harness tests MQL4 syntax. That still needs MetaEditor.

## OB_Probe_MT5.mq5

The MT5 counterpart, written to answer one specific question: does the MT5
build of the indicator publish its blocks as **buffers**, or only as drawings?

It matters because an EA can read buffers during optimisation, while drawings
do not exist there at all — MT4 and MT5 both run optimisation without a chart.
Measured on the MT4 build: buffers 0–7 all empty, so the EA has to read chart
objects, and that is why Order Block mode cannot be optimised (110 of 110
passes saw 0 blocks and 0 objects).

The script takes an `iCustom` handle, waits for `BarsCalculated`, then tries
`CopyBuffer` on 24 slots and reports which carry real values. It also dumps the
chart objects for comparison with the MT4 capture. Read-only; it never creates,
moves or deletes anything and never trades.

Run it on an MT5 chart with the indicator attached; the report lands in
`MQL5\Files\`.

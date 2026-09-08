# Eddy Grid EA — Order Block entry logic (MT4)

Work in progress: replacing the PSAR / support-resistance entry triggers in
`EddyGridEA` with Order Block triggers, driven by the FXSSI
**Order Blocks All-in-One** indicator already running on the chart.

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

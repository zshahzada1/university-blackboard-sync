const pptxgen = require("pptxgenjs");

// ─── Palette ─────────────────────────────────────────────────────────────────
const WHITE  = "FFFFFF";   // content slide backgrounds
const NIGHT  = "0F1319";   // dark slides (1, 9, 10)
const RED    = "BF2C1F";   // crimson — labels and accent mark only
const INK    = "151515";   // slide titles
const BODY   = "292929";   // body text
const GREY   = "6B7280";   // secondary / meta text
const PALE   = "C8CDD4";   // body text on dark slides

// ─── Fonts ────────────────────────────────────────────────────────────────────
const TF = "Georgia";      // slides 1 and 9 big title only
const BF = "Calibri";

const pres = new pptxgen();
pres.layout = "LAYOUT_16x9";

// ─── Helpers ─────────────────────────────────────────────────────────────────

// Slide title — pure typography, no decoration
function addHeader(slide, title) {
  slide.addText(title, {
    x: 0.25, y: 0.1, w: 9.35, h: 0.45,
    fontFace: BF, fontSize: 20, bold: true,
    color: INK, align: "left", valign: "middle", margin: 0
  });
}

// Section label — small caps, crimson, no underline
function label(slide, x, y, w, text) {
  slide.addText(text.toUpperCase(), {
    x, y, w, h: 0.25,
    fontFace: BF, fontSize: 9, bold: true,
    color: RED, charSpacing: 2, align: "left", margin: 0
  });
}

// Body text block
function body(slide, x, y, w, h, text, opts = {}) {
  slide.addText(text, {
    x, y, w, h,
    fontFace: BF, fontSize: 12, color: BODY,
    align: "left", valign: "top",
    lineSpacingMultiple: 1.25,
    margin: 0,
    ...opts
  });
}

// Italic callout — Calibri, crimson
function callout(slide, x, y, w, text) {
  slide.addText(text, {
    x, y, w, h: 0.6,
    fontFace: BF, fontSize: 13, italic: true,
    color: RED, align: "left", margin: 0
  });
}

// ─── SLIDE 1 — Title ──────────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: NIGHT };

  s.addText("Professional Advisory Report", {
    x: 0.55, y: 0.65, w: 8.8, h: 0.32,
    fontFace: BF, fontSize: 11, color: "546070",
    charSpacing: 2, align: "left", margin: 0
  });

  s.addText("Responding to\nProcurement Misconduct", {
    x: 0.55, y: 1.05, w: 9.0, h: 1.9,
    fontFace: TF, fontSize: 42, bold: true,
    color: WHITE, align: "left", valign: "top", margin: 0
  });

  s.addText("Greenfield Construction Ltd · Board Advisory Presentation", {
    x: 0.55, y: 3.05, w: 8.8, h: 0.38,
    fontFace: BF, fontSize: 13.5, color: RED,
    align: "left", margin: 0
  });

  s.addText("Bribery Act 2010  ·  Procurement Act 2023  ·  Business Ethics", {
    x: 0.55, y: 3.48, w: 8.8, h: 0.32,
    fontFace: BF, fontSize: 11, color: "4A5568",
    align: "left", margin: 0
  });

  s.addText("Hartley & Associates   |   March 2026", {
    x: 0.55, y: 5.2, w: 8.8, h: 0.28,
    fontFace: BF, fontSize: 10, color: "374151",
    align: "left", margin: 0
  });

  s.addNotes(
    "Opening.\n\n" +
    "My name is [name] from Hartley & Associates. Greenfield asked us to look at a situation that came up in early January and give the Board a straight read on what it means legally, ethically, and practically.\n\n" +
    "We have no stake in whether you win the Avondale contract. That's the point.\n\n" +
    "This session covers: what happened, the legal picture, three honest options, and what we think you should do. We'll try to keep it direct."
  );
}

// ─── SLIDE 2 — Introduction ───────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  addHeader(s, "Who we are and why we're here");

  // Left column
  label(s, 0.5, 0.65, 4.1, "Our role");
  body(s, 0.5, 0.93, 4.1, 2.8,
    "We're independent ethics advisors. Greenfield brought us in after David received the call from Richard Hale on 6 January.\n\n" +
    "Our job is to give the Board a straight read on the options. That means not telling you what you want to hear, and not softening what's at stake.\n\n" +
    "We have no commercial interest in the outcome of the tender."
  );

  label(s, 0.5, 3.88, 4.1, "Today's agenda");
  body(s, 0.5, 4.12, 4.1, 1.45,
    [
      { text: "What happened", options: { bullet: true, breakLine: true } },
      { text: "The legal exposure", options: { bullet: true, breakLine: true } },
      { text: "Three options, honestly assessed", options: { bullet: true, breakLine: true } },
      { text: "What we recommend, and why", options: { bullet: true } }
    ]
  );

  // Right column
  label(s, 5.2, 0.65, 4.4, "The question");
  s.addText(
    "Richard Hale is directly involved in evaluating your live Avondale tender. He has offered confidential scoring data and a competitor's submission in exchange for employing his son.",
    {
      x: 5.2, y: 0.93, w: 4.4, h: 1.0,
      fontFace: BF, fontSize: 12, color: BODY,
      align: "left", valign: "top", lineSpacingMultiple: 1.25, margin: 0
    }
  );

  s.addText("Accept, stay quiet, or report it?", {
    x: 5.2, y: 2.05, w: 4.4, h: 0.5,
    fontFace: BF, fontSize: 16, italic: true,
    color: RED, align: "left", margin: 0
  });

  body(s, 5.2, 2.7, 4.4, 2.55,
    "The Board hasn't responded yet. David made the right call in bringing this here before doing anything. That matters, both legally and practically."
  );

  s.addNotes(
    "Keep this quick. The Board wants to get to the substance.\n\n" +
    "The framing that matters: David did the right thing by not responding and calling this meeting. That's worth saying out loud — it's a good instinct and it gives the company options.\n\n" +
    "The 'question' on the right: read it out. Let it land. Then move on."
  );
}

// ─── SLIDE 3 — The Dilemma ────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  addHeader(s, "What happened");

  // Left column
  label(s, 0.5, 0.65, 4.2, "What Richard offered");
  body(s, 0.5, 0.93, 4.2, 4.3,
    "Richard Hale is a senior quantity surveyor at Avondale County Council. He's been a business contact for years, and the Greenfield siblings consider him a friend. He's also directly involved in evaluating your £18.5m health centre tender.\n\n" +
    "On 6 January he called David. Greenfield is currently second. Harmon Developments is ahead on price and social value. Richard offered to share the full scoring breakdown and Harmon's social value submission. Enough to know exactly what to beat.\n\n" +
    "In return: a job for his son. 'A favour between friends,' he said. 'This is just how things work.'"
  );

  // Right column
  label(s, 5.2, 0.65, 4.4, "What's at stake");
  body(s, 5.2, 0.93, 4.4, 2.35,
    "This is the largest contract Greenfield has ever pursued. Winning it would sustain 85 jobs over three years, 15 apprenticeships, and mark real progress in the public sector strategy the Board has been building.\n\n" +
    "Greenfield also invested £2.4m in new equipment on the expectation of contracts like this one."
  );

  body(s, 5.2, 3.45, 4.4, 1.8,
    "On the other side of this bid: a deprived community with real health inequalities and a housing shortage. They depend on this process being run fairly.",
    { fontSize: 11.5, color: GREY }
  );

  s.addNotes(
    "Don't rush this slide. The Board needs to hold all four dimensions before you get to the options.\n\n" +
    "On the offer: Richard is an active evaluator on a live tender. This isn't vague insider knowledge — it's specific scoring data and a competitor's confidential submission. That distinction matters legally.\n\n" +
    "On the stakes: acknowledge the financial pressure honestly. The £2.4m investment is real. Losing the contract is a real cost. The analysis that follows explains why accepting the offer would make things significantly worse, not better.\n\n" +
    "On the community: this isn't just about Greenfield's exposure. The health centre and housing development serve people with genuine need. A corrupted procurement process harms them directly."
  );
}

// ─── SLIDE 4 — Legal Context ──────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  addHeader(s, "The legal picture");

  // Left column — trimmed intro, smaller font and tighter spacing to fit with callout
  label(s, 0.5, 0.65, 4.2, "Bribery Act 2010");
  body(s, 0.5, 0.93, 4.2, 3.65,
    "Section 1: offering an advantage to induce improper conduct is a criminal offence. Offering employment to Richard's son in exchange for tender information qualifies.\n\n" +
    "Section 2: accepting such an advantage is also an offence. Receiving insider data, even without acting on it, could be enough.\n\n" +
    "Section 7 is a corporate offence: failing to prevent bribery. That exposure exists regardless of who in the company made the call.\n\n" +
    "Strict liability. Maximum sentence: 10 years. (HM Government, 2010)",
    { fontSize: 11, lineSpacingMultiple: 1.15 }
  );

  // Right column — same font and spacing
  label(s, 5.2, 0.65, 4.4, "Procurement Act 2023");
  body(s, 5.2, 0.93, 4.4, 3.65,
    "Public contracts require fair, open, transparent competition. Council evaluators sharing confidential information with a bidder is prohibited outright. Accepting it makes Greenfield complicit in that breach.\n\n" +
    "If this surfaces after award: the contract gets voided and Greenfield gets debarred from public procurement. Every future tender, gone.\n\n" +
    "Richard's disclosure is already unlawful. What Greenfield does next determines whether it becomes Greenfield's problem too. (HM Government, 2023)",
    { fontSize: 11, lineSpacingMultiple: 1.15 }
  );

  // Full-width callout — clear gap below both columns
  callout(s, 0.5, 4.75, 9.1,
    "Greenfield doesn't need to use the information for liability to arise. Receiving it without reporting could be enough."
  );

  s.addNotes(
    "The Board may not grasp the Bribery Act's reach. It's broader than most people assume.\n\n" +
    "Section 1: the offer of employment doesn't need to be accepted. Making the offer is already an offence.\n\n" +
    "Section 2: this is the one that catches Greenfield. Receiving the insider data, if it's done in a context where there's an implicit understanding of what it's for, can constitute acceptance of an advantage.\n\n" +
    "Section 7: even if David personally declines, the company still faces exposure unless it has demonstrable 'adequate procedures' in place. Reporting and documenting this is part of building that defence.\n\n" +
    "Procurement Act: debarment from public procurement is the really damaging consequence. Greenfield's entire growth strategy depends on public sector contracts. That exposure dwarfs the value of the Avondale tender.\n\n" +
    "The italic line at the bottom is the key takeaway — read it out."
  );
}

// ─── SLIDE 5 — Options ────────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  addHeader(s, "Three options");

  const optY = 0.65;
  const optW = 3.0;
  const gap  = 0.07;

  // Option A
  const ax = 0.27;
  s.addShape(pres.shapes.RECTANGLE, {
    x: ax, y: optY, w: optW, h: 0.44,
    fill: { color: RED }, line: { color: RED }
  });
  s.addText("Option A — Accept", {
    x: ax + 0.12, y: optY, w: optW - 0.15, h: 0.44,
    fontFace: BF, fontSize: 11, bold: true, color: WHITE,
    valign: "middle", align: "left", margin: 0
  });
  s.addText([
    { text: "Could win the £18.5m contract", options: { breakLine: true, color: "2A7A2A" } },
    { text: "Sustains 85 jobs in the short term", options: { breakLine: true, color: "2A7A2A" } },
    { text: " ", options: { breakLine: true, fontSize: 5 } },
    { text: "Criminal offence: Bribery Act ss.1, 2 and 7", options: { breakLine: true, color: "A01818" } },
    { text: "Contract voided and debarred from public procurement if discovered", options: { breakLine: true, color: "A01818" } },
    { text: "Reputational damage that can't be undone", options: { breakLine: true, color: "A01818" } },
    { text: "The exposure exists even if you never use the information", options: { color: "A01818" } }
  ], {
    x: ax + 0.12, y: optY + 0.52, w: optW - 0.2, h: 4.5,
    fontFace: BF, fontSize: 11,
    align: "left", valign: "top", lineSpacingMultiple: 1.28, margin: 0
  });

  // Option B
  const bx = ax + optW + gap;
  s.addShape(pres.shapes.RECTANGLE, {
    x: bx, y: optY, w: optW, h: 0.44,
    fill: { color: "5C6470" }, line: { color: "5C6470" }
  });
  s.addText("Option B — Stay quiet", {
    x: bx + 0.12, y: optY, w: optW - 0.15, h: 0.44,
    fontFace: BF, fontSize: 11, bold: true, color: WHITE,
    valign: "middle", align: "left", margin: 0
  });
  s.addText([
    { text: "No direct criminal exposure", options: { breakLine: true, color: "2A7A2A" } },
    { text: "Friendship with Richard preserved", options: { breakLine: true, color: "2A7A2A" } },
    { text: " ", options: { breakLine: true, fontSize: 5 } },
    { text: "Leaves a corrupt process running", options: { breakLine: true, color: "A01818" } },
    { text: "Silence can look like complicity if this surfaces later", options: { breakLine: true, color: "A01818" } },
    { text: "Richard may approach the next bidder", options: { breakLine: true, color: "A01818" } },
    { text: "Hard to square with 'building with integrity'", options: { color: "A01818" } }
  ], {
    x: bx + 0.12, y: optY + 0.52, w: optW - 0.2, h: 4.5,
    fontFace: BF, fontSize: 11,
    align: "left", valign: "top", lineSpacingMultiple: 1.28, margin: 0
  });

  // Option C
  const cx = bx + optW + gap;
  s.addShape(pres.shapes.RECTANGLE, {
    x: cx, y: optY, w: optW, h: 0.44,
    fill: { color: "1A3A28" }, line: { color: "1A3A28" }
  });
  s.addText("Option C — Decline and report \u2713", {
    x: cx + 0.12, y: optY, w: optW - 0.15, h: 0.44,
    fontFace: BF, fontSize: 11, bold: true, color: WHITE,
    valign: "middle", align: "left", margin: 0
  });
  s.addText([
    { text: "Full legal protection", options: { breakLine: true, color: "2A7A2A" } },
    { text: "Consistent with Greenfield's stated values", options: { breakLine: true, color: "2A7A2A" } },
    { text: "Public sector pipeline stays intact", options: { breakLine: true, color: "2A7A2A" } },
    { text: "Right outcome for the community", options: { breakLine: true, color: "2A7A2A" } },
    { text: " ", options: { breakLine: true, fontSize: 5 } },
    { text: "Real chance of losing this contract", options: { breakLine: true, color: "A01818" } },
    { text: "Short-term financial pressure", options: { color: "A01818" } }
  ], {
    x: cx + 0.12, y: optY + 0.52, w: optW - 0.2, h: 4.5,
    fontFace: BF, fontSize: 11,
    align: "left", valign: "top", lineSpacingMultiple: 1.28, margin: 0
  });

  s.addNotes(
    "Present all three options straight — don't signal the answer yet. The ethical analysis comes next.\n\n" +
    "On Option A: acknowledge the appeal honestly. The contract is significant, the jobs are real, the investment has been made. Then be clear: the legal risk here is existential. Not a compliance technicality — a criminal offence that could imprison individuals and destroy the company's ability to operate in its main growth market.\n\n" +
    "On Option B: this is the 'comfort option.' It feels like doing the right thing without the awkwardness of reporting a friend. But it leaves the corrupt process running. If Richard approaches another bidder, or if this surfaces another way, Greenfield's silence becomes evidence of something worse than it is. It also contradicts everything the company says it stands for.\n\n" +
    "On Option C: the short-term cost is real. Don't minimise it. But the long-term position is far stronger. The ethical analysis on the next two slides builds the case for it from two different directions."
  );
}

// ─── SLIDE 6 — Utilitarianism ─────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  addHeader(s, "Ethical analysis: utilitarianism");

  // Left column
  label(s, 0.5, 0.65, 3.7, "The framework");
  body(s, 0.5, 0.93, 3.7, 4.25,
    "Utilitarianism asks one question: which action produces the best outcome for the most people?\n\n" +
    "Bentham and Mill's answer: the greatest happiness for the greatest number. That means counting all affected parties, not just Greenfield. The right action is the one that produces the most welfare overall.\n\n" +
    "(Crane and Matten, 2019, pp.103–108)"
  );

  // Right column — all three applied sections in one text block, no rules between them
  label(s, 4.55, 0.65, 5.1, "Applied to each option");
  body(s, 4.55, 0.93, 5.1, 4.25,
    "If you accept: one contract won, 85 jobs in the short term. But if it surfaces, and these things do surface, the costs are enormous. Prosecution, debarment, a reputation built over two decades gone. The numbers don't add up.\n\n" +
    "If you stay quiet: you avoid direct harm to Greenfield. But the corrupt process keeps running. The community still loses out on a fair competition. Marginally better than Option A. Only marginally.\n\n" +
    "If you decline and report: you might lose this contract. That's a real cost. But Greenfield's public sector pipeline stays intact. The community gets a fair process. Richard's conduct stops before it reaches the next bidder.\n\n" +
    "One tension to be honest about: utilitarianism depends on probabilities. If detection were certain to be zero, the calculation would change. That's why the deontology analysis matters. It doesn't depend on the odds.",
    { fontSize: 11.5 }
  );

  s.addNotes(
    "Utilitarianism was developed by Bentham and elaborated by Mill. The core idea: right actions are those that produce the greatest good for the greatest number. Applied here, that means counting everyone — not just Greenfield.\n\n" +
    "Option A: the benefits are real but narrow and short-term. The costs — if this surfaces — are enormous and widespread. The net utility calculation is clearly negative.\n\n" +
    "Option C: the cost is losing one contract. The benefits are distributed across Greenfield's future, its employees' long-term security, the community, and the integrity of the procurement process. Net utility is positive.\n\n" +
    "The tension to name explicitly: a strict utilitarian might calculate differently if the probability of detection were very low. That's a genuine weakness of the theory here. Flag it — it shows the analysis is honest, not just a rubber stamp for the obvious answer. Then use it to set up the deontology slide: deontology doesn't have that problem."
  );
}

// ─── SLIDE 7 — Deontology ─────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  addHeader(s, "Ethical analysis: deontology");

  // Left column
  label(s, 0.5, 0.65, 3.7, "The framework");
  body(s, 0.5, 0.93, 3.7, 4.25,
    "Kant's deontological ethics isn't interested in outcomes. An action is right or wrong based on what it is, not what it produces.\n\n" +
    "Two tests from the categorical imperative:\n\n" +
    "(i) Universalisability: act only on rules that could apply to everyone\n\n" +
    "(ii) Humanity: treat people as ends in themselves, not as means to an end\n\n" +
    "(Fisher and Lovell, 2009, pp.88–95)"
  );

  // Right column — all three applied sections in one text block, no rules between them
  label(s, 4.55, 0.65, 5.1, "Applied to Greenfield");
  body(s, 4.55, 0.93, 5.1, 4.25,
    "Test 1, universalisability. What if every company in a public tender accepted insider information when offered? The entire procurement system collapses. The rule can't be universalised. For Kant, that settles it, regardless of how likely discovery is.\n\n" +
    "Test 2, humanity. Richard's offer uses the Council, competing bidders, and the community as instruments. Accepting makes Greenfield a participant in that. Kant's second formulation rules it out.\n\n" +
    "'Building with integrity' is a self-imposed commitment. Carroll (1991) makes the same point: ethical responsibilities constrain how economic goals are pursued. They are not traded off against them.\n\n" +
    "Two frameworks, one conclusion.",
    { fontSize: 11.5 }
  );

  s.addNotes(
    "Kant's deontological ethics holds that actions are right or wrong in themselves — not because of their consequences. This is fundamentally different from utilitarianism.\n\n" +
    "Test 1 — universalisability: ask the Board out loud — 'If every company in every public tender accepted insider information when it was offered, what happens to public procurement?' The answer is obvious. It destroys. The rule fails the universalisability test. Accepting is categorically wrong — not probably wrong, not wrong-if-caught. Wrong.\n\n" +
    "Test 2 — humanity: Richard's offer instrumentalises the Council, competing bidders, and the community. Kant's second formulation is clear: people must be treated as ends. Accepting makes Greenfield complicit in treating them as instruments.\n\n" +
    "Greenfield's mission: 'building with integrity' matters here. It's not branding — it's a self-imposed ethical commitment. A deontologist would say that makes it binding.\n\n" +
    "Carroll (1991) is a useful reference: his CSR pyramid puts ethical responsibilities above economic ones. Companies are obliged to do what's right, not just what's profitable.\n\n" +
    "Close with the contrast to utilitarianism: deontology doesn't need probability estimates. Even if the risk of getting caught were zero, the answer is the same. That's why having both frameworks land in the same place matters — the recommendation isn't dependent on a single ethical view."
  );
}

// ─── SLIDE 8 — Recommendation ─────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  addHeader(s, "What we recommend");

  label(s, 0.5, 0.65, 9.1, "Our recommendation");
  body(s, 0.5, 0.93, 9.1, 0.82,
    "Decline Richard Hale's offer and report his conduct to Avondale County Council's monitoring officer. Both ethical frameworks lead there. The table below shows what that means for each stakeholder.",
    { fontSize: 12.5 }
  );

  const tableData = [
    [
      { text: "Stakeholder", options: { bold: true, fill: { color: NIGHT }, color: WHITE, fontFace: BF, fontSize: 10, align: "left" } },
      { text: "Their interest", options: { bold: true, fill: { color: NIGHT }, color: WHITE, fontFace: BF, fontSize: 10, align: "left" } },
      { text: "Why Option C works for them", options: { bold: true, fill: { color: NIGHT }, color: WHITE, fontFace: BF, fontSize: 10, align: "left" } }
    ],
    [
      { text: "Board and shareholders", options: { fontFace: BF, fontSize: 10 } },
      { text: "Risk management, fiduciary duty", options: { fontFace: BF, fontSize: 10 } },
      { text: "Criminal liability off the table; governance obligations met", options: { fontFace: BF, fontSize: 10 } }
    ],
    [
      { text: "Employees (85 staff)", options: { fontFace: BF, fontSize: 10 } },
      { text: "Job security, long term", options: { fontFace: BF, fontSize: 10 } },
      { text: "A sustainable reputation is what secures the next contract, and the one after that", options: { fontFace: BF, fontSize: 10 } }
    ],
    [
      { text: "Community", options: { fontFace: BF, fontSize: 10 } },
      { text: "A health centre and housing they actually need", options: { fontFace: BF, fontSize: 10 } },
      { text: "Fair procurement gives them the best contractor, not the one with the best connection", options: { fontFace: BF, fontSize: 10 } }
    ],
    [
      { text: "Avondale County Council", options: { fontFace: BF, fontSize: 10 } },
      { text: "Procurement integrity", options: { fontFace: BF, fontSize: 10 } },
      { text: "Early disclosure limits their own legal exposure too", options: { fontFace: BF, fontSize: 10 } }
    ],
    [
      { text: "Industry and CIOB", options: { fontFace: BF, fontSize: 10 } },
      { text: "Professional standards", options: { fontFace: BF, fontSize: 10 } },
      { text: "Construction has taken enough reputational hits on procurement.", options: { fontFace: BF, fontSize: 10 } }
    ],
    [
      { text: "Richard Hale", options: { fontFace: BF, fontSize: 10 } },
      { text: "Friendship, personal interest", options: { fontFace: BF, fontSize: 10 } },
      { text: "Staying quiet doesn't protect him. If this surfaces another way, Greenfield's silence is a problem. Early intervention may limit the damage to him.", options: { fontFace: BF, fontSize: 10 } }
    ]
  ];

  s.addTable(tableData, {
    x: 0.5, y: 1.83, w: 9.1, h: 3.6,
    border: { pt: 0.5, color: "DCDCDC" },
    rowH: 0.5,
    align: "left",
    valign: "middle"
  });

  s.addNotes(
    "State the recommendation clearly, without hedging.\n\n" +
    "The framing that matters: two ethical frameworks got to the same answer by different routes. That's significant — it means the recommendation doesn't depend on picking the right theory.\n\n" +
    "Freeman's (1984) stakeholder approach adds a third lens: every major stakeholder group is better served by Option C than by the alternatives.\n\n" +
    "Walk through the table. A few worth pausing on:\n\n" +
    "Employees: don't conflate this contract with long-term security. Eighty-five jobs on one project are not worth destroying the company's ability to win public contracts.\n\n" +
    "Community: a health centre for people with real health inequalities deserves an honest process. That's worth saying directly.\n\n" +
    "Richard: this is the hardest part of the conversation. Acknowledge it. But staying quiet doesn't help him — if his conduct surfaces through another route, Greenfield's silence looks worse than it is. The most genuinely helpful thing is early disclosure, and if the relationship allows it, letting him know before the report is made.\n\n" +
    "Practical next steps:\n" +
    "1. David responds to Richard in writing — decline clearly, create a paper trail.\n" +
    "2. Legal counsel engaged on disclosure obligations.\n" +
    "3. Report to the Council's monitoring officer.\n" +
    "4. Internal reminder to relevant staff on procurement ethics — builds the s.7 'adequate procedures' defence."
  );
}

// ─── SLIDE 9 — Conclusion ─────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: NIGHT };

  s.addText("Conclusion", {
    x: 0.55, y: 0.2, w: 8.8, h: 0.28,
    fontFace: BF, fontSize: 10, color: "485568",
    charSpacing: 2, align: "left", margin: 0
  });

  s.addText("Your next contract depends on\nhow you handle this one.", {
    x: 0.55, y: 0.55, w: 9.0, h: 1.55,
    fontFace: TF, fontSize: 36, bold: true,
    color: WHITE, align: "left", valign: "top", margin: 0
  });

  s.addText(
    [
      { text: "Two frameworks, one answer.", options: { breakLine: true } },
      { text: " ", options: { breakLine: true, fontSize: 6 } },
      { text: "The law is clear too. But the ethical case doesn't depend on it.", options: { breakLine: true } },
      { text: " ", options: { breakLine: true, fontSize: 6 } },
      { text: "Greenfield's public sector strategy runs on its reputation. One contract is not worth the thing that gets you contracts.", options: { breakLine: true } },
      { text: " ", options: { breakLine: true, fontSize: 6 } },
      { text: "Decline in writing. Get legal counsel on the phone. Report to the Council's monitoring officer." }
    ],
    {
      x: 0.55, y: 2.3, w: 8.8, h: 3.0,
      fontFace: BF, fontSize: 13.5, color: PALE,
      align: "left", valign: "top", margin: 0, lineSpacingMultiple: 1.25
    }
  );

  s.addNotes(
    "Close with conviction. This isn't a close call.\n\n" +
    "The title line says it plainly. Greenfield's competitive edge in public sector work is its reputation. Compromising that reputation for one contract isn't pragmatic. It's self-defeating.\n\n" +
    "The logical chain:\n" +
    "Accepting means criminal liability, debarment, and a reputation that can't be rebuilt.\n" +
    "Staying quiet is legally safer but leaves the problem running and contradicts everything the company says it stands for.\n" +
    "Declining and reporting is legally protected, ethically sound, consistent with Greenfield's identity, and in the best interests of every stakeholder that matters.\n\n" +
    "Four immediate actions:\n" +
    "One — David responds to Richard today, in writing.\n" +
    "Two — legal counsel reviews disclosure obligations.\n" +
    "Three — report to the Council's monitoring officer.\n" +
    "Four — internal comms to relevant staff on procurement ethics policy.\n\n" +
    "Invite questions."
  );
}

// ─── SLIDE 10 — References ────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: NIGHT };

  s.addText("References".toUpperCase(), {
    x: 0.55, y: 0.2, w: 8.8, h: 0.28,
    fontFace: BF, fontSize: 9, bold: true,
    color: RED, charSpacing: 2, align: "left", margin: 0
  });

  const refs = [
    "Carroll, A.B. (1991) 'The Pyramid of Corporate Social Responsibility: Toward the Moral Management of Organizational Stakeholders', Business Horizons, 34(4), pp. 39–48.",
    "Crane, A. and Matten, D. (2019) Business Ethics: Managing Corporate Citizenship and Sustainability in the Age of Globalization. 5th edn. Oxford: Oxford University Press.",
    "Fisher, C. and Lovell, A. (2009) Business Ethics and Values: Individual, Corporate and International Perspectives. 3rd edn. Harlow: Pearson Education.",
    "Freeman, R.E. (1984) Strategic Management: A Stakeholder Approach. Boston: Pitman.",
    "HM Government (2010) Bribery Act 2010. London: The Stationery Office. Available at: https://www.legislation.gov.uk/ukpga/2010/23/contents (Accessed: 19 March 2026).",
    "HM Government (2023) Procurement Act 2023. London: The Stationery Office. Available at: https://www.legislation.gov.uk/ukpga/2023/54/contents (Accessed: 19 March 2026).",
    "Trevino, L.K. and Nelson, K.A. (2021) Managing Business Ethics: Straight Talk about How to Do It Right. 8th edn. Hoboken, NJ: Wiley."
  ];

  const refItems = refs.map((r, i) => ({
    text: r,
    options: { breakLine: i < refs.length - 1 }
  }));

  s.addText(refItems, {
    x: 0.55, y: 0.6, w: 8.8, h: 4.8,
    fontFace: BF, fontSize: 10.5, color: PALE,
    align: "left", valign: "top", lineSpacingMultiple: 1.35, margin: 0
  });

  s.addNotes("All references are in Harvard format and were verified before submission.");
}

// ─── Write ────────────────────────────────────────────────────────────────────
pres.writeFile({ fileName: "/home/zo/University/FA565/FA565_TaskB_Presentation.pptx" })
  .then(() => console.log("Done: /home/zo/University/FA565/FA565_TaskB_Presentation.pptx"))
  .catch(e => { console.error(e); process.exit(1); });

# Risk register and pre-mortem

Last updated: 2026-11-17  
Owner default: Founder (commercial) / Agent (engineering Docs) as noted.

| Risk | P | Impact | Early warning | Mitigation | Owner | Stop / pivot trigger |
|------|---|--------|---------------|------------|-------|----------------------|
| No willingness to pay | M | High | Empty pricing log; free-only asks | Paid continuation clause in pilot pack; log every signal | Founder | 0/5 discoveries show any fee openness → PIVOT pricing or STOP desk SKU |
| Existing products solve enough | M | High | “We have CoPilot/Sygic” closes | Demo physics + desk push delta only | Founder | Consistent “no gap” → NARROW to niche or STOP |
| Too few reachable customers | M | High | Norfolk list exhausted without meetings | Expand radius carefully; referrals | Founder | Cannot book 3 meetings in 60 days → revisit geography |
| Expensive acquisition | L | Med | Travel/time per meeting spikes | Coffee demos; avoid mass ads | Founder | CAC unknown until retention — no paid ads |
| Confidentiality blocks adoption | L | High | Legal/IT freeze | Pilot confidentiality clause; no real customer secrets in git | Founder + Agent | Refuse processing confidential docs until controls |
| AI / advisory output errors | M | High | HOS treated as legal; bad LEZ claims | VU-authority labelling; LEZ/toll honesty | Agent Docs + Founder | Misrepresentation incident → STOP claims, legal review |
| Bespoke-work trap | M | High | Custom builds per fleet | Fixed pilot scope; MoSCoW | Founder | >20% time on one-off → NARROW scope |
| Excessive onboarding/support | M | Med | Setup calls multiply | Wizard + pack; fair-use meters | Founder | Support hours > fee → raise price or cut scope |
| Low workflow frequency | L | Med | Desk unused between jobs | Measure push frequency in pilot | Founder | No weekly use → PIVOT workflow |
| Seasonal demand | L | Med | Quiet winter | Plan runway | Founder | — |
| Vendor dependency (ORS etc.) | M | High | 429 / outage | Caps, offline hybrid, policy retries | Agent | Sustained outage without fallback → risk review |
| Founder sales bottleneck | H | High | Agent idles on commercial | Backlog Founder rows; agent does Docs/evidence only | Founder | — |
| Customer churn | Unk | High | No renewals | Success criteria in pilot | Founder | 0 renewals after 2 pilots → PIVOT/STOP |
| Regulatory / safety misread | M | High | HOS/VU confusion | Legal checklist; solicitor before paid | Founder | — |
| Scope creep / gated invent | H | Med | Densify/AA/VU PRs without unlock | Anti-grind; secrets STOP; backlog discipline | Agent | Revert speculative PRs |

**P** = probability judgement (L/M/H), not a calibrated model.

## Pre-mortem

**The business failed after 12 months because…**  
…the product stayed engineering-complete while Norfolk outreach never converted to measured pilots; indicative £39 desk pricing was never tested; founder time went to gated competitor feature anxiety (CarPlay/VU/HD) instead of discovery; and advisory HOS/LEZ claims were oversold, triggering trust or legal pushback without solicitor cover.

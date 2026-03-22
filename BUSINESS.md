# Wick Business Model: Option D (Hybrid)

**Status:** Planned — not yet implemented
**Date:** 2026-03-22

## Summary

Free open-source tool (distribution/brand) + bespoke Pro contracts (revenue).
The anti-detection capability is only valuable if it stays effective, and it
only stays effective if it stays rare.

## Free Tier (Open Source)

- Cronet-only (Chrome TLS fingerprint) — handles ~70% of sites
- Content extraction + MCP server
- CAPTCHA user-in-the-loop
- Costs us $0 (runs on user's hardware)
- Top of funnel — developers discover Wick, use it, hit limits

## Pro Tier ($500-5K/month, Bespoke)

- CEF + stealth patches (never public)
- Custom fingerprint profile per client (different Chrome version, plugin set, stealth variants)
- Continuous stealth updates (monitor what's being detected)
- Dedicated support + SLA for specific target domains
- Onboarding: "tell us which sites you need, we'll make sure they work"

## Target Sectors (High-Value, Low-Volume)

| Sector | What they access | Why they'd pay |
|---|---|---|
| Financial data / hedge funds | SEC filings, earnings transcripts, alternative data | Time-sensitive, high $ value per data point |
| Competitive intelligence | Competitor pricing, product catalogs, job postings | Strategic decisions depend on accurate data |
| Compliance / legal | Regulatory filings, sanctions lists, court records | Required by law, can't afford gaps |
| Market research | Review aggregation, sentiment analysis, trend tracking | Agencies charge $10K+/month for this |
| Real estate / property data | Listings, zoning, permit records, tax assessments | Time-sensitive, location-specific |
| Travel / pricing | Airline/hotel rates, availability | Revenue optimization depends on it |

## What We DON'T Target

- Mass content scraping (news aggregation, SEO farms)
- Social media scraping (Meta will sue)
- Email harvesting, lead scraping
- Anything at >10K pages/day per client

## Why NOT Other Models

**Usage-based (Bright Data style):** Volume is the signal. High volume = easy to
detect = fast arms race. We'd compete with Bright Data on their turf with
1/1000th their resources.

**IP sharing network (Hola style):** Legally radioactive. Hola class-action,
FBI's March 2026 PSA, Google's IPIDEA takedown. Even if technically defensible,
reputational risk kills the business.

## Revenue Projections (Conservative)

| Timeline | Free users | Pro clients | MRR |
|---|---|---|---|
| 3 months | 500 | 3 | $2.5K |
| 6 months | 2,000 | 10 | $10K |
| 12 months | 10,000 | 25 | $30K |
| 24 months | 50,000 | 50 | $75K |

## Implementation Steps (When Ready)

1. Find 3 pilot customers (hedge funds, competitive intel firms, compliance shops)
2. Build custom fingerprint system (unique profile per Pro client)
3. Set up Stripe billing (simple subscription, manual onboarding)
4. Write Pro landing page ("tell us what you need" — qualification-based sales)
5. Build client dashboard (usage stats, success rates, blocked domains)

## Key Insight

The anti-detection capability is only valuable if it stays effective, and it
only stays effective if it stays rare. 50 clients × 100 pages/day = 5,000
requests/day total — Cloudflare won't build a detection model for that.

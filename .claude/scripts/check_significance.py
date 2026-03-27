#!/usr/bin/env python3
"""
check_significance.py — Two-sample t-test for Parameter Golf submissions.

Usage:
    python3 .claude/scripts/check_significance.py "OURS" "SOTA"

OURS and SOTA are comma-separated bpb floats.

Example:
    python3 .claude/scripts/check_significance.py \
        "1.1372,1.1368,1.1375" \
        "1.14271,1.14298,1.14260"

Exit code: 0 = PASS, 1 = FAIL
"""

import sys
import statistics
import math


def ttest_ind_less(a: list[float], b: list[float]) -> float:
    """One-tailed Welch's t-test: H1 = mean(a) < mean(b). Returns p-value."""
    n_a, n_b = len(a), len(b)
    mean_a = statistics.mean(a)
    mean_b = statistics.mean(b)
    var_a = statistics.variance(a) if n_a > 1 else 0.0
    var_b = statistics.variance(b) if n_b > 1 else 0.0

    se = math.sqrt(var_a / n_a + var_b / n_b)
    if se == 0:
        return 0.0 if mean_a < mean_b else 1.0

    t = (mean_a - mean_b) / se

    # Welch–Satterthwaite degrees of freedom
    num = (var_a / n_a + var_b / n_b) ** 2
    den = (var_a / n_a) ** 2 / (n_a - 1) + (var_b / n_b) ** 2 / (n_b - 1)
    df = num / den if den > 0 else min(n_a, n_b) - 1

    # One-tailed p-value via regularised incomplete beta (scipy-free approximation)
    # Uses the relation: p = I(df/(df+t²), df/2, 0.5) / 2  for t < 0
    p_two = _t_cdf_two_tailed(t, df)
    p_one = p_two / 2 if t < 0 else 1.0 - p_two / 2
    return p_one


def _t_cdf_two_tailed(t: float, df: float) -> float:
    """Approximate two-tailed p-value for t-distribution."""
    # Abramowitz & Stegun approximation via regularised incomplete beta
    x = df / (df + t * t)
    return _betai(df / 2, 0.5, x)


def _betai(a: float, b: float, x: float) -> float:
    """Regularised incomplete beta function via continued fraction."""
    if x < 0 or x > 1:
        return 0.0
    if x == 0:
        return 0.0
    if x == 1:
        return 1.0
    lbeta = math.lgamma(a) + math.lgamma(b) - math.lgamma(a + b)
    front = math.exp(math.log(x) * a + math.log(1 - x) * b - lbeta) / a
    return front * _betacf(a, b, x)


def _betacf(a: float, b: float, x: float, max_iter: int = 200) -> float:
    """Lentz continued fraction for incomplete beta."""
    qab = a + b
    qap = a + 1
    qam = a - 1
    c, d = 1.0, 1.0 - qab * x / qap
    if abs(d) < 1e-30:
        d = 1e-30
    d = 1.0 / d
    h = d
    for m in range(1, max_iter + 1):
        m2 = 2 * m
        aa = m * (b - m) * x / ((qam + m2) * (a + m2))
        d = 1.0 + aa * d
        c = 1.0 + aa / c
        if abs(d) < 1e-30:
            d = 1e-30
        if abs(c) < 1e-30:
            c = 1e-30
        d = 1.0 / d
        h *= d * c
        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))
        d = 1.0 + aa * d
        c = 1.0 + aa / c
        if abs(d) < 1e-30:
            d = 1e-30
        if abs(c) < 1e-30:
            c = 1e-30
        d = 1.0 / d
        delta = d * c
        h *= delta
        if abs(delta - 1.0) < 1e-10:
            break
    return h


def parse_scores(s: str) -> list[float]:
    return [float(v.strip()) for v in s.split(",") if v.strip()]


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2

    ours = parse_scores(sys.argv[1])
    sota = parse_scores(sys.argv[2])

    if len(ours) < 2 or len(sota) < 2:
        print("ERROR: need at least 2 values per group for significance testing")
        return 2

    mean_ours = statistics.mean(ours)
    std_ours = statistics.stdev(ours)
    mean_sota = statistics.mean(sota)
    std_sota = statistics.stdev(sota)
    improvement = mean_sota - mean_ours
    p_value = ttest_ind_less(ours, sota)

    MIN_IMPROVEMENT = 0.005
    MAX_P = 0.01

    pass_improvement = improvement >= MIN_IMPROVEMENT
    pass_p = p_value < MAX_P
    verdict = "PASS" if (pass_improvement and pass_p) else "FAIL"

    print(f"Our mean:     {mean_ours:.5f} ± {std_ours:.5f}  (n={len(ours)}, seeds: {ours})")
    print(f"SOTA mean:    {mean_sota:.5f} ± {std_sota:.5f}  (n={len(sota)}, seeds: {sota})")
    print(f"Improvement:  {improvement:+.5f} bpb  [{'PASS' if pass_improvement else 'FAIL'} — need >= {MIN_IMPROVEMENT}]")
    print(f"p-value:      {p_value:.5f}          [{'PASS' if pass_p else 'FAIL'} — need < {MAX_P}]")
    print(f"VERDICT:      {verdict}")

    if verdict == "FAIL":
        if not pass_improvement:
            print(f"\nShortfall: {MIN_IMPROVEMENT - improvement:.5f} bpb below threshold.")
            print("Action: stack the next plan or investigate quant gap.")
        if not pass_p:
            print(f"\nInsufficient significance (p={p_value:.4f} > {MAX_P}).")
            print("Action: run more seeds or achieve larger improvement.")

    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())

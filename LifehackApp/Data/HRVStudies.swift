import Foundation

enum HRVStudies {
    static let all: [Study] = [
        Study(
            title: "An Overview of Heart Rate Variability Metrics and Norms",
            authors: "Shaffer F, Ginsberg JP",
            journal: "Frontiers in Public Health",
            year: "2017",
            doi: "10.3389/fpubh.2017.00258",
            url: URL(string: "https://www.frontiersin.org/articles/10.3389/fpubh.2017.00258/full"),
            summary: "Accessible review covering HRV metrics (time & frequency domains), physiology of vagal control, measurement considerations, and normative ranges.",
            takeaways: [
                "Use consistent conditions (time of day, posture, breathing) for comparisons.",
                "SDNN and RMSSD are reliable time-domain metrics; RMSSD best reflects vagal tone.",
                "Short-term (1–5 min) measures are practical for daily self-tracking."
            ],
            category: .general
        ),
        Study(
            title: "Heart Rate Variability and Cardiac Vagal Tone in Psychophysiological Research—Recommendations",
            authors: "Laborde S, Mosley E, Thayer JF",
            journal: "Frontiers in Psychology",
            year: "2017",
            doi: nil,
            url: URL(string: "https://www.frontiersin.org/articles/10.3389/fpsyg.2017.00213/full"),
            summary: "Guidelines for planning, recording, and reporting HRV to improve data quality and interpretation.",
            takeaways: [
                "Control for confounders (caffeine, alcohol, heavy meals, stress, illness).",
                "Prefer RMSSD for short-term resting measures; avoid overinterpreting LF/HF.",
                "Report breathing rate and sampling details for reproducibility."
            ],
            category: .methodology
        ),
        Study(
            title: "The LF/HF Ratio Does Not Accurately Measure Cardiac Sympatho-Vagal Balance",
            authors: "Billman GE",
            journal: "Frontiers in Physiology",
            year: "2013",
            doi: "10.3389/fphys.2013.00026",
            url: URL(string: "https://www.frontiersin.org/articles/10.3389/fphys.2013.00026/full"),
            summary: "Critical analysis of LF/HF showing it’s not a reliable index of sympathetic/parasympathetic balance.",
            takeaways: [
                "Avoid using LF/HF as a single marker of 'stress vs. recovery'.",
                "Use time-domain measures (e.g., RMSSD) or validated context-specific protocols.",
                "Interpret frequency domain with caution and context."
            ],
            category: .methodology
        ),
        Study(
            title: "Monitoring Training Status with HR Measures: Do All Roads Lead to Rome?",
            authors: "Buchheit M",
            journal: "Frontiers in Physiology",
            year: "2014",
            doi: "10.3389/fphys.2014.00073",
            url: URL(string: "https://www.frontiersin.org/articles/10.3389/fphys.2014.00073/full"),
            summary: "Practical review on using HRV to guide training load, recovery, and adaptation across sports.",
            takeaways: [
                "Track rolling baselines of morning RMSSD; look for meaningful deviations.",
                "Use HRV trends to individualize intensity and recovery days.",
                "Combine HRV with session RPE, sleep, and wellness for best decisions."
            ],
            category: .training
        ),
        Study(
            title: "Cardiac Parasympathetic Reactivation Following Exercise: Implications for HRV",
            authors: "Stanley J, Peake JM, Buchheit M",
            journal: "Sports Medicine",
            year: "2013",
            doi: "10.1007/s40279-013-0072-1",
            url: URL(string: "https://link.springer.com/article/10.1007/s40279-013-0072-1"),
            summary: "How recovery HR and post-exercise HRV reflect autonomic reactivation and readiness.",
            takeaways: [
                "Slower HR recovery and reduced post-exercise HRV can indicate fatigue.",
                "Include low-intensity days and adequate sleep to restore parasympathetic tone.",
                "Use consistent post-exercise protocols for trend tracking."
            ],
            category: .training
        ),
        Study(
            title: "Heart Rate Variability Biofeedback for Anxiety and Depression: Systematic Review & Meta-Analysis",
            authors: "Lehrer PM, Kaur K, Sharma A, et al.",
            journal: "International Journal of Environmental Research and Public Health",
            year: "2020",
            doi: "10.3390/ijerph17218013",
            url: URL(string: "https://www.mdpi.com/1660-4601/17/21/8013"),
            summary: "HRV biofeedback improves mental health outcomes with moderate effects in anxiety/depression.",
            takeaways: [
                "5–6 breaths/min (resonance breathing) 10–20 min/day improves HRV and mood.",
                "Combine with mindfulness/sleep hygiene for durable benefits.",
                "Track resting RMSSD to monitor adaptation."
            ],
            category: .breathing
        ),
        Study(
            title: "Heart Rate Variability and Training Intensity Distribution in Elite Rowers",
            authors: "Plews DJ, Laursen PB, Stanley J, Kilding AE, Buchheit M",
            journal: "International Journal of Sports Physiology and Performance",
            year: "2014",
            doi: nil,
            url: URL(string: "https://journals.humankinetics.com/view/journals/ijspp/9/6/article-p1026.xml"),
            summary: "Morning HRV relates to training intensity distribution and performance in elite endurance athletes.",
            takeaways: [
                "Higher HRV trends generally align with better readiness and tolerance for intensity.",
                "Use HRV-guided periodization to balance high/low-intensity blocks.",
                "Individual responses vary—monitor your own baseline and variance."
            ],
            category: .training
        )
    ]
}

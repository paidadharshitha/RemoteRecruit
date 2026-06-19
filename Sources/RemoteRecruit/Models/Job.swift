// Job.swift
// RemoteRecruit

import Foundation

public struct Job: Codable, Hashable, Identifiable, Sendable {

    public let id: String
    public let title: String
    public let companyName: String
    public let location: String
    public let salaryRange: String
    public let jobDescription: String
    public let tags: [String]
    /// The date this job was posted. Defaults to the current date if not provided.
    public let postedDate: Date

    /// The job domain this listing belongs to (e.g. iOS Developer, Backend Engineer).
    public let domain: JobDomain
    /// The career experience level for this listing (e.g. Student, Fresher, Experienced).
    public let experienceLevel: ExperienceLevel

    public init(
        id: String = UUID().uuidString,
        title: String,
        companyName: String,
        location: String,
        salaryRange: String,
        jobDescription: String,
        tags: [String] = [],
        postedDate: Date? = nil,
        domain: JobDomain = .iosDeveloper,
        experienceLevel: ExperienceLevel = .student
    ) {
        self.id = id
        self.title = title
        self.companyName = companyName
        self.location = location
        self.salaryRange = salaryRange
        self.jobDescription = jobDescription
        self.tags = tags
        self.postedDate = postedDate ?? Date()
        self.domain = domain
        self.experienceLevel = experienceLevel
    }
}

// MARK: - Mock Data

public enum MockData {

    // MARK: - Helpers

    private static let companiesByDomain: [String: [String]] = [
        "iOS Developer": [
            "Apple", "Stripe", "Airbnb", "Lyft", "Robinhood",
            "Square", "Duolingo", "Spotify", "Uber", "Discord"
        ],
        "Backend Engineer": [
            "Notion", "HashiCorp", "Cloudflare", "Twilio", "Datadog",
            "MongoDB", "Confluent", "Elastic", "PagerDuty", "LaunchDarkly"
        ],
        "Product Designer": [
            "Figma", "Canva", "Pinterest", "Dropbox", "Airtable",
            "InVision", "Miro", "Framer", "Webflow", "Abstract"
        ],
        "Data Scientist": [
            "Spotify", "Netflix", "Tesla", "Airbnb", "Stripe",
            "Instacart", "Doordash", "Pinterest", "Coinbase", "Databricks"
        ],
        "Software Developer": [
            "Google", "Microsoft", "Amazon", "Meta", "LinkedIn",
            "Atlassian", "Salesforce", "Oracle", "SAP", "Adobe"
        ],
        "Data Engineer": [
            "Snowflake", "Databricks", "Palantir", "Stone", "Netflix",
            "Airbnb", "Uber", "Spotify", "Figma", "Lyft"
        ],
        "Embedded Systems Engineer": [
            "Texas Instruments", "NXP Semiconductors", "STMicroelectronics", "Qualcomm",
            "Bosch", "ARM Holdings", "Renesas", "Microchip Technology"
        ],
        "Hardware Engineer": [
            "Apple", "Intel", "AMD", "NVIDIA", "Broadcom",
            "Qualcomm", "MediaTek", "Marvell", "Analog Devices", "Texas Instruments"
        ],
        "Power Systems Engineer": [
            "Siemens Energy", "General Electric", "ABB Group", "Schneider Electric",
            "Hitachi Energy", "Eaton", "Toshiba", "Mitsubishi Electric"
        ],
        "Control Systems Engineer": [
            "Rockwell Automation", "Siemens", "Honeywell", "Emerson Electric",
            "Yokogawa", "ABB Group", "Schneider Electric", "Bosch Rexroth"
        ],
        "Web Developer": [
            "Vercel", "Netlify", "Shopify", "Webflow", "Figma",
            "Atlassian", "Stripe", "Airbnb", "GitHub", "Linear"
        ],
        "AI Specialist": [
            "OpenAI", "Anthropic", "Google DeepMind", "Meta AI",
            "Microsoft Research", "Hugging Face", "Stability AI", "Cohere"
        ],
        "VLSI Engineer": [
            "Intel", "AMD", "NVIDIA", "Qualcomm", "Broadcom",
            "ARM Holdings", "MediaTek", "Marvell", "Synopsys", "Cadence"
        ],
        "Firmware Developer": [
            "Apple", "Nordic Semiconductor", "Espressif", "Silicon Labs",
            "Microchip Technology", "NXP", "STMicroelectronics", "Renesas"
        ],
        "Electrical Designer": [
            "ABB Group", "Siemens", "Schneider Electric", "Eaton",
            "General Electric", "Rockwell Automation", "Honeywell", "Emerson Electric"
        ],
        "CAD Designer": [
            "Tesla", "SpaceX", "Boeing", "Lockheed Martin", "General Motors",
            "Ford", "Dyson", "John Deere", "Caterpillar", "GE Aviation"
        ],
        "Product Design Engineer": [
            "Apple", "Dyson", "Tesla", "Nike", "Samsung",
            "Microsoft", "Logitech", "Sonos", "Fitbit", "GoPro"
        ],
        "Thermal Engineer": [
            "Apple", "Intel", "AMD", "NVIDIA", "Qualcomm",
            "Tesla", "SpaceX", "Boeing", "General Electric", "Honeywell"
        ]
    ]

    private static let locations = [
        "San Francisco, CA (Remote)", "New York, NY (Remote)",
        "Seattle, WA (Remote)", "Austin, TX (Remote)",
        "Remote (Worldwide)", "London, UK (Remote)",
        "Berlin, Germany (Remote)", "Toronto, Canada (Remote)",
        "Stockholm, Sweden (Remote)", "Sydney, Australia (Remote)"
    ]

    private static func company(for domain: String, index: Int) -> String {
        // "Data Engineer Intern" key differs from companiesByDomain — normalize it
        let resolvedKey = domain == "Data Engineer Intern" ? "Data Engineer" : domain
        guard let pool = companiesByDomain[resolvedKey] else {
            assertionFailure("No company pool for domain: \(domain)")
            return "Tech Company"
        }
        return pool[index % pool.count]
    }

    private static func location(for index: Int) -> String {
        locations[index % locations.count]
    }

    // MARK: - Internship Pool (25 jobs)

    private static let internTitlesByDomain: [String: [String]] = [
        "iOS Developer": [
            "iOS Intern", "iOS Intern – SwiftUI Focus", "Mobile Intern – iOS Platform",
            "iOS Development Intern", "iOS Intern – App Prototyping", "Intern – iOS Apps",
            "iOS Co-op Engineer"
        ],
        "Backend Engineer": [
            "Backend Intern", "Backend Trainee", "Backend Intern – API Services",
            "Server-Side Intern", "Cloud Infrastructure Intern", "Intern – Backend Systems"
        ],
        "Product Designer": [
            "UX Design Intern", "Product Design Intern", "UI/UX Intern – Mobile",
            "Design Intern – Consumer Products", "Visual Design Intern",
            "Intern – Product Design"
        ],
        "Data Scientist": [
            "Data Science Intern", "ML Intern", "Data Analytics Intern",
            "Applied ML Intern", "Intern – Data Engineering", "Research Intern – ML"
        ],
        "Software Developer": [
            "SDE Intern", "Software Engineering Intern", "Full-Stack Intern",
            "Developer Intern – Web Platform", "Software Intern – Cloud Native",
            "Intern – Application Development"
        ],
        "Data Engineer Intern": [
            "Data Engineering Intern", "ETL Intern", "Data Pipeline Intern",
            "Big Data Intern", "Analytics Engineering Intern", "Intern – Data Infrastructure"
        ],
        "Embedded Systems Engineer": [
            "Embedded Systems Intern", "Firmware Intern – RTOS", "IoT Engineering Intern",
            "Microcontroller Intern", "Embedded Software Intern – C/C++", "Intern – Firmware Development"
        ],
        "Hardware Engineer": [
            "Hardware Engineering Intern", "VLSI Design Intern", "FPGA Intern",
            "PCB Design Intern", "RTL Design Intern", "Intern – Silicon Validation"
        ],
        "Power Systems Engineer": [
            "Power Systems Intern", "Electrical Engineering Intern", "Substation Design Intern",
            "Transmission Planning Intern", "Power Distribution Intern", "Intern – Grid Operations"
        ],
        "Control Systems Engineer": [
            "Control Systems Intern", "Automation Intern – PLC/SCADA", "Instrumentation Intern",
            "Process Control Intern", "Industrial Automation Intern", "Intern – SCADA Systems"
        ],
        "Web Developer": [
            "Web Development Intern", "Frontend Intern – React", "UI Engineering Intern",
            "Web Intern – JavaScript", "Full-Stack Intern – Web", "Intern – Responsive Web"
        ],
        "AI Specialist": [
            "AI/ML Research Intern", "Deep Learning Intern", "NLP Intern",
            "Computer Vision Intern", "AI Engineering Intern", "Intern – Machine Learning"
        ],
        "VLSI Engineer": [
            "VLSI Design Intern", "RTL Design Intern", "ASIC Intern",
            "SoC Design Intern", "Verification Intern – Verilog", "Intern – Tapeout Planning"
        ],
        "Firmware Developer": [
            "Firmware Intern – MCU", "Embedded C Intern", "Bare-Metal Intern",
            "Driver Development Intern", "Bootloader Intern", "Intern – RTOS Firmware"
        ],
        "Electrical Designer": [
            "Electrical Design Intern", "Schematic Design Intern", "Panel Layout Intern",
            "Wiring Design Intern", "Revit Electrical Intern", "Intern – AutoCAD Electrical"
        ],
        "CAD Designer": [
            "CAD Design Intern", "3D Modeling Intern – SolidWorks", "Design Intern – CATIA",
            "Mechanical Drafting Intern", "CAD Intern – Creo", "Intern – NX Modeling"
        ],
        "Product Design Engineer": [
            "Product Design Intern", "Prototyping Intern", "DFM Intern",
            "Design Engineering Intern", "Tolerancing Intern", "Intern – GD&T Analysis"
        ],
        "Thermal Engineer": [
            "Thermal Engineering Intern", "Heat Transfer Intern", "CFD Analysis Intern",
            "Thermal Management Intern", "FEA Intern – Thermal", "Intern – Cooling Systems"
        ]
    ]

    // MARK: - Entry-Level Pool (50 jobs)

    private static let fresherTitlesByDomain: [String: [String]] = [
        "iOS Developer": [
            "Associate iOS Developer", "Junior iOS Engineer", "iOS Developer",
            "Junior Mobile Developer – iOS", "Associate Mobile Engineer",
            "iOS Engineer I", "Junior Swift Developer", "Associate Developer – iOS",
            "Mobile Developer I – iOS", "iOS Software Developer – Junior",
            "Junior iOS App Developer", "Associate Engineer – SwiftUI", "iOS Developer – Entry Level"
        ],
        "Backend Engineer": [
            "Associate Backend Engineer", "Junior Backend Developer", "Backend Developer",
            "Junior Server Engineer", "Associate Software Engineer – Backend",
            "Backend Engineer I", "Junior API Developer", "Associate Developer – Services",
            "Junior Platform Engineer", "Backend Developer – Entry Level",
            "Junior Cloud Developer", "Associate Engineer – Distributed Systems", "Software Developer I – Backend"
        ],
        "Product Designer": [
            "Associate Product Designer", "Junior UX Designer", "UI Designer – Fresher",
            "Junior Interaction Designer", "Associate Designer – Product",
            "Product Designer I", "Junior Visual Designer", "Associate UX Researcher",
            "Designer I – Product", "Product Designer – Entry Level",
            "Junior UI Designer", "Associate Designer – Mobile",
            "Junior Designer – Consumer"
        ],
        "Data Scientist": [
            "Associate Data Scientist", "Junior Data Analyst", "Data Scientist I",
            "Junior ML Engineer", "Associate Analyst – Data Science",
            "Junior Research Scientist", "Data Analyst – Fresher",
            "Associate Data Engineer – Analytics", "Junior Applied Scientist",
            "Data Scientist – Entry Level", "Junior Analytics Engineer",
            "Associate Scientist – ML", "Data Scientist – Junior Level"
        ],
        "Software Developer": [
            "Associate Software Developer", "Junior Software Engineer", "SDE I",
            "Software Developer – Entry Level", "Associate Developer – Full Stack",
            "Junior Full-Stack Developer", "Software Engineer I", "Associate Engineer – Platform",
            "Junior Developer – Cloud Apps", "Application Developer – Junior",
            "Associate SDE – Backend", "Junior Developer – Systems"
        ],
        "Data Engineer": [
            "Associate Data Engineer", "Junior Data Engineer", "Data Engineer I",
            "Junior ETL Developer", "Associate Engineer – Data Pipelines",
            "Junior Analytics Engineer", "Data Engineer – Entry Level",
            "Associate Engineer – Data Warehouse", "Junior Big Data Developer",
            "Data Platform Engineer – Junior", "Associate Engineer – Streaming"
        ],
        "Embedded Systems Engineer": [
            "Associate Embedded Engineer", "Junior Embedded Developer", "Embedded Engineer I",
            "Junior Firmware Engineer", "Associate Engineer – IoT", "Embedded Developer – Entry Level",
            "Junior RTOS Developer", "Associate Engineer – Microcontrollers",
            "Junior Embedded C Developer", "Firmware Engineer – Junior",
            "Associate Engineer – Automotive Embedded"
        ],
        "Hardware Engineer": [
            "Associate Hardware Engineer", "Junior Hardware Developer", "Hardware Engineer I",
            "Junior VLSI Engineer", "Associate Engineer – FPGA", "Hardware Engineer – Entry Level",
            "Junior PCB Designer", "Associate Engineer – RTL Design",
            "Junior Verification Engineer", "Hardware Design Engineer – Junior",
            "Associate Engineer – Silicon Design"
        ],
        "Power Systems Engineer": [
            "Associate Power Engineer", "Junior Power Systems Engineer", "Power Engineer I",
            "Junior Substation Engineer", "Associate Engineer – Transmission",
            "Power Systems Engineer – Entry Level", "Junior Distribution Engineer",
            "Associate Engineer – Grid Planning", "Junior Electrical Design Engineer",
            "Protection Engineer – Junior", "Associate Engineer – Renewable Energy"
        ],
        "Control Systems Engineer": [
            "Associate Control Engineer", "Junior Control Systems Engineer", "Control Engineer I",
            "Junior Automation Engineer", "Associate Engineer – PLC/SCADA",
            "Control Systems Engineer – Entry Level", "Junior Instrumentation Engineer",
            "Associate Engineer – Process Control", "Junior DCS Engineer",
            "Industrial Automation Engineer – Junior", "Associate Engineer – PID Control"
        ],
        "Web Developer": [
            "Junior Web Developer", "Associate Frontend Developer", "Web Developer I",
            "Junior React Developer", "Associate Developer – JavaScript", "Entry-Level Web Developer",
            "Junior UI Engineer", "Associate Developer – CSS/HTML", "Web Developer – Entry Level",
            "Junior Full-Stack Developer – Web", "Associate Developer – Vue.js"
        ],
        "AI Specialist": [
            "Junior AI Engineer", "Associate ML Engineer", "AI Engineer I",
            "Entry-Level Data Scientist – AI", "Junior Deep Learning Engineer",
            "Associate NLP Engineer", "AI Engineer – Entry Level", "Junior Computer Vision Engineer",
            "Associate Engineer – AI/ML", "Entry-Level AI Researcher"
        ],
        "VLSI Engineer": [
            "Junior VLSI Engineer", "Associate RTL Design Engineer", "VLSI Engineer I",
            "Junior ASIC Developer", "Associate Verification Engineer", "VLSI Engineer – Entry Level",
            "Junior SoC Designer", "Associate Engineer – Timing Analysis",
            "Junior Physical Design Engineer", "Associate Engineer – Tapeout",
            "VLSI Design Engineer – Junior"
        ],
        "Firmware Developer": [
            "Junior Firmware Developer", "Associate Embedded C Developer", "Firmware Engineer I",
            "Junior Driver Developer", "Associate Engineer – Bare-Metal", "Firmware Developer – Entry Level",
            "Junior Bootloader Engineer", "Associate Engineer – MCU",
            "Junior RTOS Developer – Firmware", "Embedded Firmware Developer – Junior",
            "Associate Engineer – Device Drivers"
        ],
        "Electrical Designer": [
            "Junior Electrical Designer", "Associate Schematic Designer", "Electrical Designer I",
            "Junior Panel Designer", "Associate Engineer – Wiring Design", "Electrical Designer – Entry Level",
            "Junior Revit Electrical Designer", "Associate Engineer – AutoCAD Electrical",
            "Junior Building Systems Designer", "Associate Engineer – Power Distribution",
            "Electrical Design Engineer – Junior"
        ],
        "CAD Designer": [
            "Junior CAD Designer", "Associate 3D Modeler", "CAD Designer I",
            "Junior SolidWorks Designer", "Associate Designer – CATIA", "CAD Designer – Entry Level",
            "Junior Creo Designer", "Associate Engineer – NX Modeling",
            "Junior Mechanical Drafter", "Associate Designer – 2D/3D CAD",
            "CAD Design Engineer – Junior"
        ],
        "Product Design Engineer": [
            "Junior Product Design Engineer", "Associate Design Engineer", "Product Design Engineer I",
            "Entry-Level Prototyping Engineer", "Associate Engineer – DFM", "Product Design Engineer – Entry Level",
            "Junior Mechanical Designer", "Associate Engineer – GD&T",
            "Junior Consumer Product Designer", "Associate Engineer – Tolerancing",
            "Product Design Engineer – Junior Level"
        ],
        "Thermal Engineer": [
            "Junior Thermal Engineer", "Associate Heat Transfer Engineer", "Thermal Engineer I",
            "Junior CFD Analyst", "Associate Engineer – Thermal Management", "Thermal Engineer – Entry Level",
            "Junior FEA Analyst – Thermal", "Associate Engineer – Cooling Systems",
            "Junior Thermal Design Engineer", "Associate Engineer – Electronics Cooling",
            "Thermal Engineer – Junior Level"
        ]
    ]

    // MARK: - Experienced Pool (30 jobs)

    private static let experiencedTitlesByDomain: [String: [String]] = [
        "iOS Developer": [
            "Senior iOS Engineer", "Lead iOS Developer", "Staff iOS Engineer",
            "Senior Mobile Architect", "Principal iOS Developer",
            "Senior Swift Engineer", "Lead Mobile Developer – iOS",
            "Senior Engineer – iOS Platform"
        ],
        "Backend Engineer": [
            "Senior Backend Engineer", "Lead Backend Architect",
            "Staff Backend Engineer", "Principal Backend Developer",
            "Senior Platform Engineer", "Lead API Architect",
            "Senior Distributed Systems Engineer", "Principal Cloud Architect"
        ],
        "Product Designer": [
            "Senior Product Designer", "Lead UX Designer",
            "Staff Product Designer", "Principal Designer",
            "Senior Design Lead", "Lead Interaction Designer",
            "Senior UX Strategist"
        ],
        "Data Scientist": [
            "Staff Data Scientist", "Lead ML Engineer",
            "Senior Data Scientist", "Principal Data Scientist",
            "Lead Research Scientist", "Senior Applied Scientist",
            "Staff ML Engineer"
        ],
        "Software Developer": [
            "Senior Software Engineer", "Staff SDE", "Principal Software Engineer",
            "Senior Full-Stack Developer", "Lead Software Architect",
            "Staff Platform Engineer", "Senior Developer – Cloud Native",
            "Principal Engineer – Systems"
        ],
        "Data Engineer": [
            "Senior Data Engineer", "Staff Data Engineer", "Principal Data Engineer",
            "Senior Analytics Engineer", "Lead Data Architect",
            "Staff Data Platform Engineer", "Senior Big Data Engineer",
            "Principal Engineer – Data Infrastructure"
        ],
        "Embedded Systems Engineer": [
            "Senior Embedded Engineer", "Staff Firmware Engineer", "Principal Embedded Architect",
            "Senior IoT Engineer", "Lead RTOS Developer",
            "Staff Embedded Systems Architect", "Senior Firmware Architect",
            "Principal Engineer – Embedded Platforms"
        ],
        "Hardware Engineer": [
            "Senior Hardware Engineer", "Staff VLSI Engineer", "Principal Hardware Architect",
            "Senior FPGA Engineer", "Lead Silicon Designer",
            "Staff Verification Engineer", "Senior PCB Design Architect",
            "Principal Engineer – ASIC Design"
        ],
        "Power Systems Engineer": [
            "Senior Power Systems Engineer", "Staff Power Engineer", "Principal Power Architect",
            "Senior Transmission Planner", "Lead Grid Engineer",
            "Staff Substation Designer", "Senior Protection Engineer",
            "Principal Engineer – Renewable Integration"
        ],
        "Control Systems Engineer": [
            "Senior Control Systems Engineer", "Staff Automation Architect", "Principal Controls Engineer",
            "Senior SCADA Engineer", "Lead Process Control Engineer",
            "Staff Instrumentation Architect", "Senior DCS Engineer",
            "Principal Engineer – Industrial Automation"
        ],
        "Web Developer": [
            "Senior Web Developer", "Staff Frontend Engineer", "Principal Web Architect",
            "Senior React Engineer", "Lead UI Engineer",
            "Staff Web Platform Engineer", "Senior Full-Stack Developer – Web"
        ],
        "AI Specialist": [
            "Senior AI Engineer", "Staff ML Engineer", "Principal AI Scientist",
            "Senior Deep Learning Engineer", "Lead NLP Engineer",
            "Staff Computer Vision Engineer", "Senior AI Research Scientist",
            "Principal Engineer – AI Platform"
        ],
        "VLSI Engineer": [
            "Senior VLSI Engineer", "Staff RTL Architect", "Principal VLSI Designer",
            "Senior ASIC Engineer", "Lead SoC Architect",
            "Staff Verification Architect", "Senior Physical Design Engineer",
            "Principal Engineer – Tapeout"
        ],
        "Firmware Developer": [
            "Senior Firmware Developer", "Staff Embedded Firmware Architect", "Principal Firmware Engineer",
            "Senior RTOS Developer", "Lead Device Driver Engineer",
            "Staff Bare-Metal Architect", "Senior Bootloader Engineer",
            "Principal Engineer – Firmware Platforms"
        ],
        "Electrical Designer": [
            "Senior Electrical Designer", "Staff Schematic Architect", "Principal Electrical Designer",
            "Senior Panel Design Engineer", "Lead Power Distribution Engineer",
            "Staff Building Systems Designer", "Senior Revit Electrical Specialist",
            "Principal Engineer – Electrical Systems"
        ],
        "CAD Designer": [
            "Senior CAD Designer", "Staff 3D Modeling Architect", "Principal CAD Engineer",
            "Senior SolidWorks Specialist", "Lead CATIA Designer",
            "Staff Creo Engineer", "Senior Mechanical Drafting Lead",
            "Principal Engineer – CAD Systems"
        ],
        "Product Design Engineer": [
            "Senior Product Design Engineer", "Staff Design Engineer", "Principal Product Designer",
            "Senior DFM Engineer", "Lead Prototyping Specialist",
            "Staff Mechanical Design Architect", "Senior Consumer Product Designer",
            "Principal Engineer – Product Design"
        ],
        "Thermal Engineer": [
            "Senior Thermal Engineer", "Staff Heat Transfer Specialist", "Principal Thermal Architect",
            "Senior CFD Engineer", "Lead Thermal Management Engineer",
            "Staff FEA Specialist – Thermal", "Senior Electronics Cooling Engineer",
            "Principal Engineer – Thermal Systems"
        ]
    ]

    // MARK: - Generator

    private static func randomPostedDate(offset: Int = 0) -> Date {
        Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...14), to: Date()) ?? Date()
    }

    private static func generateInternJobs() -> [Job] {
        var jobs: [Job] = []
        let descriptionsByDomain: [String: String] = [
            "iOS Developer": "Assist in building iOS features using Swift and SwiftUI. Shadow mentors, participate in code reviews, and contribute to small-scale feature development.",
            "Backend Engineer": "Learn to build and maintain scalable API services. Work with databases, write unit tests, and shadow senior engineers on infrastructure projects.",
            "Product Designer": "Support the design team with wireframes, prototypes, and user research. Collaborate on design systems and contribute to consumer product features.",
            "Data Scientist": "Work on data pipelines, exploratory analysis, and model prototyping. Collaborate with ML engineers on recommendation and analytics systems.",
            "Software Developer": "Contribute to full-stack application development using modern frameworks. Write clean, tested code and participate in agile sprints with cross-functional teams.",
            "Data Engineer Intern": "Build and maintain data pipelines and ETL processes. Work with cloud data services and learn big data processing frameworks.",
            "Embedded Systems Engineer": "Develop firmware for microcontrollers and real-time operating systems. Work on IoT device integration, sensor interfaces, and low-level C/C++ programming.",
            "Hardware Engineer": "Assist in VLSI design, FPGA prototyping, and PCB layout. Learn hardware description languages and participate in silicon validation testing.",
            "Power Systems Engineer": "Support substation design, load flow analysis, and protection coordination. Learn power system simulation tools and grid planning methodologies.",
            "Control Systems Engineer": "Work on PLC programming, SCADA system configuration, and industrial automation projects. Assist with instrumentation and process control design.",
            "Web Developer": "Build responsive web interfaces using modern frontend frameworks. Contribute to component libraries, accessibility improvements, and performance optimization.",
            "AI Specialist": "Work on AI/ML model prototyping, data preprocessing, and experiment tracking. Collaborate with research engineers on cutting-edge deep learning projects.",
            "VLSI Engineer": "Assist in RTL design, logic synthesis, and timing closure for ASIC/SoC projects. Learn industry-standard EDA tools and verification methodologies.",
            "Firmware Developer": "Develop low-level firmware for microcontrollers and embedded processors. Work on device drivers, bootloaders, and hardware abstraction layers.",
            "Electrical Designer": "Create electrical schematics, panel layouts, and wiring diagrams using CAD tools. Learn building systems design and power distribution standards.",
            "CAD Designer": "Create 3D models and engineering drawings using SolidWorks, CATIA, or Creo. Support mechanical design projects with drafting and tolerancing.",
            "Product Design Engineer": "Assist in product design from concept to prototype. Work on DFM analysis, GD&T specifications, and rapid prototyping.",
            "Thermal Engineer": "Support thermal analysis and cooling system design for electronic and mechanical systems. Learn CFD and FEA simulation tools."
        ]
        let tagsByDomain: [String: [String]] = [
            "iOS Developer": ["iOS", "Swift", "SwiftUI", "Internship"],
            "Backend Engineer": ["Backend", "API", "Python", "Internship"],
            "Product Designer": ["Design", "UX/UI", "Figma", "Internship"],
            "Data Scientist": ["Data Science", "Python", "ML", "Internship"],
            "Software Developer": ["Software", "Full-Stack", "Python", "Internship"],
            "Data Engineer Intern": ["Data Engineering", "ETL", "SQL", "Internship"],
            "Embedded Systems Engineer": ["Embedded", "C/C++", "RTOS", "IoT", "Internship"],
            "Hardware Engineer": ["Hardware", "VLSI", "FPGA", "Verilog", "Internship"],
            "Power Systems Engineer": ["Power Systems", "Electrical", "Protection", "Internship"],
            "Control Systems Engineer": ["Control Systems", "PLC", "SCADA", "Automation", "Internship"],
            "Web Developer": ["Web", "Frontend", "React", "JavaScript", "Internship"],
            "AI Specialist": ["AI", "ML", "Deep Learning", "Python", "Internship"],
            "VLSI Engineer": ["VLSI", "RTL", "Verilog", "ASIC", "Internship"],
            "Firmware Developer": ["Firmware", "Embedded C", "MCU", "Bare-Metal", "Internship"],
            "Electrical Designer": ["Electrical Design", "Schematic", "AutoCAD", "Internship"],
            "CAD Designer": ["CAD", "SolidWorks", "3D Modeling", "Internship"],
            "Product Design Engineer": ["Product Design", "DFM", "Prototyping", "Internship"],
            "Thermal Engineer": ["Thermal", "CFD", "FEA", "Heat Transfer", "Internship"]
        ]
        let stipends = ["$25/hr stipend", "$30/hr stipend", "$28/hr stipend", "$35/hr stipend", "$22/hr stipend"]

        for domain in internTitlesByDomain {
            let titles = domain.value
            let domainKey = domain.key
            // Handle the "Data Engineer Intern" key which differs from enum rawValue
            let jobDomain: JobDomain
            if domainKey == "Data Engineer Intern" {
                jobDomain = .dataEngineer
            } else {
                jobDomain = JobDomain(rawValue: domainKey) ?? .iosDeveloper
            }
            for (i, title) in titles.enumerated() {
                let desc = descriptionsByDomain[domainKey] ?? "Contribute to real-world engineering projects as part of a collaborative team."
                let tags = tagsByDomain[domainKey] ?? ["Engineering", "Internship"]
                jobs.append(Job(
                    title: title,
                    companyName: company(for: domainKey, index: i),
                    location: location(for: i),
                    salaryRange: stipends[i % stipends.count],
                    jobDescription: desc,
                    tags: tags,
                    postedDate: randomPostedDate(),
                    domain: jobDomain,
                    experienceLevel: .student
                ))
            }
        }
        return jobs
    }

    private static func generateFresherJobs() -> [Job] {
        var jobs: [Job] = []
        let descriptionsByDomain: [String: String] = [
            "iOS Developer": "Build iOS features using Swift and SwiftUI with guidance from senior engineers. Write tests, fix bugs, and ship features to production.",
            "Backend Engineer": "Develop and maintain API services and database schemas. Write tests, participate in on-call rotations, and deploy services to production.",
            "Product Designer": "Design and ship product features end-to-end. Conduct user research, create prototypes, and collaborate with engineering to deliver polished UI.",
            "Data Scientist": "Build data pipelines, train ML models, and deliver analytics dashboards. Collaborate with product teams to drive data-informed decisions.",
            "Software Developer": "Build and maintain full-stack applications using modern frameworks. Ship features, write tests, and participate in code reviews with senior engineers.",
            "Data Engineer": "Design and build data pipelines, ETL workflows, and analytics infrastructure. Work with SQL, Spark, and cloud data platforms.",
            "Embedded Systems Engineer": "Develop embedded firmware and drivers for microcontroller-based systems. Work on RTOS, communication protocols, and hardware-software integration.",
            "Hardware Engineer": "Design and verify digital hardware blocks using Verilog/VHDL. Work on FPGA prototyping, timing analysis, and silicon verification.",
            "Power Systems Engineer": "Design and analyze power distribution networks, substations, and protection systems. Perform load flow studies and fault analysis.",
            "Control Systems Engineer": "Design and implement industrial control systems using PLCs, SCADA, and DCS platforms. Configure instrumentation and process automation logic.",
            "Web Developer": "Build and maintain responsive web applications using modern frontend frameworks. Ship features, optimize performance, and ensure cross-browser compatibility.",
            "AI Specialist": "Build and deploy AI/ML models for production use cases. Work on data pipelines, model evaluation, and integrate AI services into applications.",
            "VLSI Engineer": "Design RTL blocks, run simulations, and support timing closure for SoC projects. Work with synthesis and place-and-route tools.",
            "Firmware Developer": "Develop and test firmware for embedded devices. Write device drivers, implement communication protocols, and debug hardware-software integration issues.",
            "Electrical Designer": "Design electrical systems, create schematics and panel layouts, and ensure compliance with electrical codes and safety standards.",
            "CAD Designer": "Create detailed 3D models, assemblies, and engineering drawings. Perform tolerance analysis and support manufacturing documentation.",
            "Product Design Engineer": "Design mechanical components and assemblies from concept through prototyping. Apply DFM principles and GD&T specifications.",
            "Thermal Engineer": "Perform thermal analysis and design cooling solutions for electronic systems. Use CFD and FEA tools to validate thermal performance."
        ]
        let tagsByDomain: [String: [String]] = [
            "iOS Developer": ["iOS", "Swift", "SwiftUI", "Entry Level"],
            "Backend Engineer": ["Backend", "API", "Go", "Entry Level"],
            "Product Designer": ["Design", "UX/UI", "Figma", "Entry Level"],
            "Data Scientist": ["Data Science", "Python", "ML", "Entry Level"],
            "Software Developer": ["Software", "Full-Stack", "JavaScript", "Entry Level"],
            "Data Engineer": ["Data Engineering", "ETL", "SQL", "Entry Level"],
            "Embedded Systems Engineer": ["Embedded", "C/C++", "RTOS", "Entry Level"],
            "Hardware Engineer": ["Hardware", "VLSI", "FPGA", "Entry Level"],
            "Power Systems Engineer": ["Power Systems", "Electrical", "Protection", "Entry Level"],
            "Control Systems Engineer": ["Control Systems", "PLC", "SCADA", "Entry Level"],
            "Web Developer": ["Web", "Frontend", "React", "Entry Level"],
            "AI Specialist": ["AI", "ML", "Deep Learning", "Entry Level"],
            "VLSI Engineer": ["VLSI", "RTL", "Verilog", "Entry Level"],
            "Firmware Developer": ["Firmware", "Embedded C", "MCU", "Entry Level"],
            "Electrical Designer": ["Electrical Design", "Schematic", "AutoCAD", "Entry Level"],
            "CAD Designer": ["CAD", "SolidWorks", "3D Modeling", "Entry Level"],
            "Product Design Engineer": ["Product Design", "DFM", "Prototyping", "Entry Level"],
            "Thermal Engineer": ["Thermal", "CFD", "FEA", "Entry Level"]
        ]
        let salaries = ["$70k – $95k", "$65k – $90k", "$75k – $100k", "$68k – $88k", "$72k – $96k"]

        for domain in fresherTitlesByDomain {
            let titles = domain.value
            let domainKey = domain.key
            let jobDomain = JobDomain(rawValue: domainKey) ?? .iosDeveloper
            let desc = descriptionsByDomain[domainKey] ?? "Develop and ship production-quality features with guidance from senior engineers."
            let tags = tagsByDomain[domainKey] ?? ["Engineering", "Entry Level"]
            for (i, title) in titles.enumerated() {
                jobs.append(Job(
                    title: title,
                    companyName: company(for: domainKey, index: i + 3),
                    location: location(for: i + 2),
                    salaryRange: salaries[i % salaries.count],
                    jobDescription: desc,
                    tags: tags,
                    postedDate: randomPostedDate(),
                    domain: jobDomain,
                    experienceLevel: .fresher
                ))
            }
        }
        return jobs
    }

    private static func generateExperiencedJobs() -> [Job] {
        var jobs: [Job] = []
        let descriptionsByDomain: [String: String] = [
            "iOS Developer": "Architect and lead iOS platform development. Define technical strategy, mentor engineers, and drive performance across the mobile stack.",
            "Backend Engineer": "Design and operate large-scale distributed systems. Lead architectural decisions, manage infrastructure, and mentor the engineering team.",
            "Product Designer": "Lead product design strategy and vision. Drive design system evolution, mentor designers, and align design with business goals.",
            "Data Scientist": "Lead ML and data science initiatives. Design models at scale, publish research, and partner with leadership on data strategy.",
            "Software Developer": "Architect large-scale software systems and lead cross-functional engineering teams. Define technical standards and drive engineering excellence.",
            "Data Engineer": "Architect data platforms and lead data infrastructure teams. Design real-time streaming pipelines and optimize data warehouse performance.",
            "Embedded Systems Engineer": "Architect embedded firmware platforms and lead hardware-software integration. Define RTOS strategy and drive product-level embedded innovation.",
            "Hardware Engineer": "Lead VLSI/ASIC design and silicon verification teams. Drive chip architecture decisions, tapeout planning, and foundry coordination.",
            "Power Systems Engineer": "Lead power system planning and design for utility-scale projects. Define protection philosophy, grid reliability standards, and renewable integration strategy.",
            "Control Systems Engineer": "Lead industrial automation and control system architecture. Define SCADA/DCS strategy, lead commissioning, and mentor automation engineers.",
            "Web Developer": "Architect and lead web platform development. Define frontend strategy, drive performance optimization, and mentor the web engineering team.",
            "AI Specialist": "Lead AI/ML initiatives and define the AI platform strategy. Design production ML systems, publish research, and mentor the AI engineering team.",
            "VLSI Engineer": "Lead VLSI/ASIC design and verification teams. Drive chip architecture decisions, tapeout planning, and foundry coordination.",
            "Firmware Developer": "Lead firmware platform architecture and define embedded software strategy. Drive RTOS decisions, boot architecture, and device driver standards.",
            "Electrical Designer": "Lead electrical design teams for complex building and industrial systems. Define design standards, review schematics, and ensure code compliance.",
            "CAD Designer": "Lead CAD design teams and define mechanical design standards. Drive toolchain strategy, review complex assemblies, and mentor drafters.",
            "Product Design Engineer": "Lead product design from concept through manufacturing. Define DFM strategy, drive prototyping, and mentor junior design engineers.",
            "Thermal Engineer": "Lead thermal management strategy for complex systems. Define cooling architecture, drive CFD/FEA methodology, and mentor thermal engineers."
        ]
        let tagsByDomain: [String: [String]] = [
            "iOS Developer": ["iOS", "Swift", "SwiftUI", "Architecture"],
            "Backend Engineer": ["Backend", "Distributed Systems", "Go", "Architecture"],
            "Product Designer": ["Design", "UX Strategy", "Figma", "Leadership"],
            "Data Scientist": ["Data Science", "ML", "Python", "Leadership"],
            "Software Developer": ["Software", "Architecture", "System Design", "Leadership"],
            "Data Engineer": ["Data Engineering", "Spark", "Kafka", "Architecture"],
            "Embedded Systems Engineer": ["Embedded", "Firmware", "RTOS", "Architecture"],
            "Hardware Engineer": ["Hardware", "VLSI", "FPGA", "Architecture"],
            "Power Systems Engineer": ["Power Systems", "Grid Planning", "Leadership"],
            "Control Systems Engineer": ["Control Systems", "SCADA", "Leadership", "Architecture"],
            "Web Developer": ["Web", "Frontend", "Architecture", "Leadership"],
            "AI Specialist": ["AI", "ML", "Architecture", "Leadership"],
            "VLSI Engineer": ["VLSI", "ASIC", "Architecture", "Leadership"],
            "Firmware Developer": ["Firmware", "Embedded", "Architecture", "Leadership"],
            "Electrical Designer": ["Electrical Design", "Architecture", "Leadership"],
            "CAD Designer": ["CAD", "Mechanical Design", "Leadership", "Architecture"],
            "Product Design Engineer": ["Product Design", "DFM", "Leadership", "Architecture"],
            "Thermal Engineer": ["Thermal", "CFD", "Architecture", "Leadership"]
        ]
        let salaries = ["$150k – $220k", "$160k – $230k", "$140k – $200k", "$170k – $240k", "$155k – $225k"]

        for domain in experiencedTitlesByDomain {
            let titles = domain.value
            let domainKey = domain.key
            let jobDomain = JobDomain(rawValue: domainKey) ?? .iosDeveloper
            let desc = descriptionsByDomain[domainKey] ?? "Lead engineering teams, define architecture, and drive technical excellence across the organization."
            let tags = tagsByDomain[domainKey] ?? ["Engineering", "Leadership"]
            for (i, title) in titles.enumerated() {
                jobs.append(Job(
                    title: title,
                    companyName: company(for: domainKey, index: i + 5),
                    location: location(for: i + 4),
                    salaryRange: salaries[i % salaries.count],
                    jobDescription: desc,
                    tags: tags,
                    postedDate: randomPostedDate(),
                    domain: jobDomain,
                    experienceLevel: .experienced
                ))
            }
        }
        return jobs
    }

    // MARK: - Combined Repository

    /// Programmatic baseline dataset: 25 intern + 50 fresher + 30 experienced = 105 unique jobs
    /// covering every combination of Domain × Experience Level.
    public static let sampleJobs: [Job] = {
        var all = generateInternJobs()   // 25
        all += generateFresherJobs()      // 50
        all += generateExperiencedJobs()  // 30
        print("Successfully initialized \(all.count) dynamic mockup job vectors.")
        return all
    }()
}

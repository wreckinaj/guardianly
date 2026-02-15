import 'package:flutter/material.dart';

class Policy extends StatefulWidget {
  const Policy({super.key});

  @override
  State<Policy> createState() => PolicyState();
}

class PolicyState extends State<Policy> {
  final Map<String, bool> expandedSections = {
    'privacy': false,
    'terms': false,
    'community': false,
    'safety': false,
    'data': false,
    'copyright': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Policies & Guidelines',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.policy,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Policies & Guidelines',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Learn about our policies and your rights',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Divider(thickness: 1),
              
              const SizedBox(height: 16),
              
              // Policy Sections
              Expanded(
                child: ListView(
                  children: [
                    // Privacy Policy
                    buildPolicySection(
                      id: 'privacy',
                      icon: Icons.privacy_tip,
                      iconColor: Colors.blue,
                      title: 'Privacy Policy',
                      subtitle: 'How we collect and use your data',
                      lastUpdated: 'Updated: Feb 10, 2026',
                      content: '''
Your privacy is important to us. This Privacy Policy explains how Guardianly collects, uses, and protects your personal information when you use our application.

Information We Collect:
• Location data to provide navigation and alerts
• Account information (email, name)
• Usage data to improve our services
• Device information for app functionality

How We Use Your Information:
• Provide and maintain our services
• Send you alerts and notifications
• Improve and personalize your experience
• Ensure safety and security

Data Sharing:
We do not sell your personal information. We may share anonymized data with partners to improve services.

Your Rights:
You can request access to your data, ask for corrections, or delete your account at any time.
''',
                    ),
                    
                    // Terms of Service
                    buildPolicySection(
                      id: 'terms',
                      icon: Icons.description,
                      iconColor: Colors.green,
                      title: 'Terms of Service',
                      subtitle: 'Rules and guidelines for using Guardianly',
                      lastUpdated: 'Updated: Jan 15, 2026',
                      content: '''
By using Guardianly, you agree to these Terms of Service.

Acceptable Use:
• Use the app for lawful purposes only
• Respect other users and their privacy
• Do not attempt to circumvent security measures
• Provide accurate location information

User Accounts:
You are responsible for maintaining the confidentiality of your account. Notify us immediately of any unauthorized use.

Service Availability:
We strive to provide reliable service but do not guarantee uninterrupted access. We may modify or discontinue features with notice.

Limitation of Liability:
Guardianly is not liable for indirect damages arising from use of our services. We are not responsible for third-party content or services.
''',
                    ),
                    
                    // Community Guidelines
                    buildPolicySection(
                      id: 'community',
                      icon: Icons.people,
                      iconColor: Colors.purple,
                      title: 'Community Guidelines',
                      subtitle: 'Be kind, be respectful, be safe',
                      lastUpdated: 'Updated: Dec 5, 2025',
                      content: '''
Our community is built on respect and helpfulness. Follow these guidelines:

Do:
• Share accurate and helpful information
• Report safety concerns immediately
• Respect diverse perspectives
• Keep discussions constructive

Don't:
• Post inappropriate or harmful content
• Harass or bully other users
• Share false or misleading information
• Violate others' privacy

Enforcement:
Violations may result in content removal, account suspension, or permanent ban depending on severity.
''',
                    ),
                    
                    // Safety Policy
                    buildPolicySection(
                      id: 'safety',
                      icon: Icons.shield,
                      iconColor: Colors.orange,
                      title: 'Safety Policy',
                      subtitle: 'Your safety is our priority',
                      lastUpdated: 'Updated: Feb 1, 2026',
                      content: '''
Guardianly is committed to user safety.

Emergency Features:
• Emergency alerts are prioritized
• Location sharing is always opt-in
• Panic button for immediate assistance

Reporting:
Users can report safety concerns directly through the app. All reports are reviewed within 24 hours.

Safe Navigation:
Always pay attention to your surroundings. Do not use the app while driving. Navigation instructions are for reference only.

Child Safety:
Users under 13 require parental consent. We comply with COPPA regulations.
''',
                    ),
                    
                    // Data Policy
                    buildPolicySection(
                      id: 'data',
                      icon: Icons.storage,
                      iconColor: Colors.teal,
                      title: 'Data Policy',
                      subtitle: 'How we handle your information',
                      lastUpdated: 'Updated: Jan 20, 2026',
                      content: '''
Our Data Policy outlines our commitment to protecting your information.

Data Collection:
• Location history (opt-in)
• Search queries
• Route preferences
• App usage statistics

Data Retention:
Location data is retained for 30 days. Account information is retained until account deletion. Anonymized data may be kept longer for analytics.

Security:
We use industry-standard encryption. Regular security audits are performed. Access to personal data is strictly limited.

Data Portability:
You can export your data at any time through account settings.
''',
                    ),
                    
                    // Copyright Policy
                    buildPolicySection(
                      id: 'copyright',
                      icon: Icons.copyright,
                      iconColor: Colors.red,
                      title: 'Copyright Policy',
                      subtitle: 'Intellectual property rights',
                      lastUpdated: 'Updated: Nov 10, 2025',
                      content: '''
Respecting intellectual property is important to us.

Our Content:
Map data © Mapbox. Guardianly logo and branding are trademarks. App design and code are protected by copyright.

User Content:
Users retain ownership of content they create. By posting, you grant us license to display and share content within the app.

DMCA Compliance:
We respond to valid copyright infringement notices. Submit takedown requests through our designated agent.

Fair Use:
Limited use of copyrighted material for commentary, criticism, or education may be considered fair use.
''',
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildPolicySection({
    required String id,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String lastUpdated,
    required String content,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Column(
        children: [
          // Header
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lastUpdated,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                expandedSections[id]! 
                  ? Icons.keyboard_arrow_up 
                  : Icons.keyboard_arrow_down,
                color: Colors.grey.shade600,
              ),
              onPressed: () {
                setState(() {
                  expandedSections[id] = !expandedSections[id]!;
                });
              },
            ),
          ),
          
          // Expandable content
          AnimatedCrossFade(
            firstChild: Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: expandedSections[id]! 
              ? CrossFadeState.showFirst 
              : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}
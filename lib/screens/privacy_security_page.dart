import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacySecurityPage extends StatelessWidget {
  const PrivacySecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Privacy Policy for Tiketi Mkononi',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last updated: May 17, 2025',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Introduction',
              content:
                  'This Privacy Policy describes Our policies and procedures on the collection, use and disclosure of Your information when You use the Service and tells You about Your privacy rights and how the law protects You.\n\n'
                  'We use Your Personal data to provide and improve the Service. By using the Service, You agree to the collection and use of information in accordance with this Privacy Policy.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Interpretation and Definitions',
              children: [
                _buildSubSection(
                  title: 'Interpretation',
                  content:
                      'The words of which the initial letter is capitalized have meanings defined under the following conditions. The following definitions shall have the same meaning regardless of whether they appear in singular or in plural.',
                ),
                _buildSubSection(
                  title: 'Definitions',
                  children: [
                    _buildDefinitionItem(
                      term: 'Account',
                      definition:
                          'means a unique account created for You to access our Service or parts of our Service.',
                    ),
                    _buildDefinitionItem(
                      term: 'Affiliate',
                      definition:
                          'means an entity that controls, is controlled by or is under common control with a party, where "control" means ownership of 50% or more of the shares, equity interest or other securities entitled to vote for election of directors or other managing authority.',
                    ),
                    _buildDefinitionItem(
                      term: 'Application',
                      definition:
                          'refers to Tiketi Mkononi, the software program provided by the Company.',
                    ),
                    _buildDefinitionItem(
                      term: 'Company',
                      definition:
                          '(referred to as either "the Company", "We", "Us" or "Our" in this Agreement) refers to Tanzani Electronics Labs Company Limited, Dar es Salaam, Tanzania.',
                    ),
                    _buildDefinitionItem(
                      term: 'Country',
                      definition: 'refers to: Tanzania',
                    ),
                    _buildDefinitionItem(
                      term: 'Device',
                      definition:
                          'means any device that can access the Service such as a computer, a cellphone or a digital tablet.',
                    ),
                    _buildDefinitionItem(
                      term: 'Personal Data',
                      definition:
                          'is any information that relates to an identified or identifiable individual.',
                    ),
                    _buildDefinitionItem(
                      term: 'Service',
                      definition: 'refers to the Application.',
                    ),
                    _buildDefinitionItem(
                      term: 'Service Provider',
                      definition:
                          'means any natural or legal person who processes the data on behalf of the Company. It refers to third-party companies or individuals employed by the Company to facilitate the Service, to provide the Service on behalf of the Company, to perform services related to the Service or to assist the Company in analyzing how the Service is used.',
                    ),
                    _buildDefinitionItem(
                      term: 'Usage Data',
                      definition:
                          'refers to data collected automatically, either generated by the use of the Service or from the Service infrastructure itself (for example, the duration of a page visit).',
                    ),
                    _buildDefinitionItem(
                      term: 'You',
                      definition:
                          'means the individual accessing or using the Service, or the company, or other legal entity on behalf of which such individual is accessing or using the Service, as applicable.',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Collecting and Using Your Personal Data',
              children: [
                _buildSubSection(
                  title: 'Types of Data Collected',
                  children: [
                    _buildSubSection(
                      title: 'Personal Data',
                      content:
                          'While using Our Service, We may ask You to provide Us with certain personally identifiable information that can be used to contact or identify You. Personally identifiable information may include, but is not limited to:',
                      children: [
                        _buildListItem('Email address'),
                        _buildListItem('First name and last name'),
                        _buildListItem('Phone number'),
                        _buildListItem(
                            'Address, State, Province, ZIP/Postal code, City'),
                        _buildListItem('Usage Data'),
                      ],
                    ),
                    _buildSubSection(
                      title: 'Usage Data',
                      content:
                          'Usage Data is collected automatically when using the Service.\n\n'
                          'Usage Data may include information such as Your Device\'s Internet Protocol address (e.g. IP address), browser type, browser version, the pages of our Service that You visit, the time and date of Your visit, the time spent on those pages, unique device identifiers and other diagnostic data.\n\n'
                          'When You access the Service by or through a mobile device, We may collect certain information automatically, including, but not limited to, the type of mobile device You use, Your mobile device unique ID, the IP address of Your mobile device, Your mobile operating system, the type of mobile Internet browser You use, unique device identifiers and other diagnostic data.\n\n'
                          'We may also collect information that Your browser sends whenever You visit our Service or when You access the Service by or through a mobile device.',
                    ),
                    _buildSubSection(
                      title: 'Information Collected while Using the Application',
                      content:
                          'While using Our Application, in order to provide features of Our Application, We may collect, with Your prior permission:',
                      children: [
                        _buildListItem(
                            'Pictures and other information from your Device\'s camera and photo library'),
                      ],
                      additionalContent:
                          'We use this information to provide features of Our Service, to improve and customize Our Service. The information may be uploaded to the Company\'s servers and/or a Service Provider\'s server or it may be simply stored on Your device.\n\n'
                          'You can enable or disable access to this information at any time, through Your Device settings.',
                    ),
                  ],
                ),
                _buildSubSection(
                  title: 'Use of Your Personal Data',
                  content:
                      'The Company may use Personal Data for the following purposes:',
                  children: [
                    _buildListItem(
                        'To provide and maintain our Service, including to monitor the usage of our Service.'),
                    _buildListItem(
                        'To manage Your Account: to manage Your registration as a user of the Service. The Personal Data You provide can give You access to different functionalities of the Service that are available to You as a registered user.'),
                    _buildListItem(
                        'For the performance of a contract: the development, compliance and undertaking of the purchase contract for the products, items or services You have purchased or of any other contract with Us through the Service.'),
                    _buildListItem(
                        'To contact You: To contact You by email, telephone calls, SMS, or other equivalent forms of electronic communication, such as a mobile application\'s push notifications regarding updates or informative communications related to the functionalities, products or contracted services, including the security updates, when necessary or reasonable for their implementation.'),
                    _buildListItem(
                        'To provide You with news, special offers and general information about other goods, services and events which we offer that are similar to those that you have already purchased or enquired about unless You have opted not to receive such information.'),
                    _buildListItem(
                        'To manage Your requests: To attend and manage Your requests to Us.'),
                    _buildListItem(
                        'For business transfers: We may use Your information to evaluate or conduct a merger, divestiture, restructuring, reorganization, dissolution, or other sale or transfer of some or all of Our assets, whether as a going concern or as part of bankruptcy, liquidation, or similar proceeding, in which Personal Data held by Us about our Service users is among the assets transferred.'),
                    _buildListItem(
                        'For other purposes: We may use Your information for other purposes, such as data analysis, identifying usage trends, determining the effectiveness of our promotional campaigns and to evaluate and improve our Service, products, services, marketing and your experience.'),
                  ],
                  additionalContent:
                      'We may share Your personal information in the following situations:\n\n'
                      '• With Service Providers: We may share Your personal information with Service Providers to monitor and analyze the use of our Service, to contact You.\n'
                      '• For business transfers: We may share or transfer Your personal information in connection with, or during negotiations of, any merger, sale of Company assets, financing, or acquisition of all or a portion of Our business to another company.\n'
                      '• With Affiliates: We may share Your information with Our affiliates, in which case we will require those affiliates to honor this Privacy Policy. Affiliates include Our parent company and any other subsidiaries, joint venture partners or other companies that We control or that are under common control with Us.\n'
                      '• With business partners: We may share Your information with Our business partners to offer You certain products, services or promotions.\n'
                      '• With other users: when You share personal information or otherwise interact in the public areas with other users, such information may be viewed by all users and may be publicly distributed outside.\n'
                      '• With Your consent: We may disclose Your personal information for any other purpose with Your consent.',
                ),
                _buildSubSection(
                  title: 'Retention of Your Personal Data',
                  content:
                      'The Company will retain Your Personal Data only for as long as is necessary for the purposes set out in this Privacy Policy. We will retain and use Your Personal Data to the extent necessary to comply with our legal obligations (for example, if we are required to retain your data to comply with applicable laws), resolve disputes, and enforce our legal agreements and policies.\n\n'
                      'The Company will also retain Usage Data for internal analysis purposes. Usage Data is generally retained for a shorter period of time, except when this data is used to strengthen the security or to improve the functionality of Our Service, or We are legally obligated to retain this data for longer time periods.',
                ),
                _buildSubSection(
                  title: 'Transfer of Your Personal Data',
                  content:
                      'Your information, including Personal Data, is processed at the Company\'s operating offices and in any other places where the parties involved in the processing are located. It means that this information may be transferred to — and maintained on — computers located outside of Your state, province, country or other governmental jurisdiction where the data protection laws may differ than those from Your jurisdiction.\n\n'
                      'Your consent to this Privacy Policy followed by Your submission of such information represents Your agreement to that transfer.\n\n'
                      'The Company will take all steps reasonably necessary to ensure that Your data is treated securely and in accordance with this Privacy Policy and no transfer of Your Personal Data will take place to an organization or a country unless there are adequate controls in place including the security of Your data and other personal information.',
                ),
                _buildSubSection(
                  title: 'Delete Your Personal Data',
                  content:
                      'You have the right to delete or request that We assist in deleting the Personal Data that We have collected about You.\n\n'
                      'Our Service may give You the ability to delete certain information about You from within the Service.\n\n'
                      'You may update, amend, or delete Your information at any time by signing in to Your Account, if you have one, and visiting the account settings section that allows you to manage Your personal information. You may also contact Us to request access to, correct, or delete any personal information that You have provided to Us.\n\n'
                      'Please note, however, that We may need to retain certain information when we have a legal obligation or lawful basis to do so.',
                ),
                _buildSubSection(
                  title: 'Disclosure of Your Personal Data',
                  children: [
                    _buildSubSection(
                      title: 'Business Transactions',
                      content:
                          'If the Company is involved in a merger, acquisition or asset sale, Your Personal Data may be transferred. We will provide notice before Your Personal Data is transferred and becomes subject to a different Privacy Policy.',
                    ),
                    _buildSubSection(
                      title: 'Law enforcement',
                      content:
                          'Under certain circumstances, the Company may be required to disclose Your Personal Data if required to do so by law or in response to valid requests by public authorities (e.g. a court or a government agency).',
                    ),
                    _buildSubSection(
                      title: 'Other legal requirements',
                      content:
                          'The Company may disclose Your Personal Data in the good faith belief that such action is necessary to:',
                      children: [
                        _buildListItem('Comply with a legal obligation'),
                        _buildListItem(
                            'Protect and defend the rights or property of the Company'),
                        _buildListItem(
                            'Prevent or investigate possible wrongdoing in connection with the Service'),
                        _buildListItem(
                            'Protect the personal safety of Users of the Service or the public'),
                        _buildListItem('Protect against legal liability'),
                      ],
                    ),
                  ],
                ),
                _buildSubSection(
                  title: 'Security of Your Personal Data',
                  content:
                      'The security of Your Personal Data is important to Us, but remember that no method of transmission over the Internet, or method of electronic storage is 100% secure. While We strive to use commercially acceptable means to protect Your Personal Data, We cannot guarantee its absolute security.',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Children\'s Privacy',
              content:
                  'Our Service does not address anyone under the age of 13. We do not knowingly collect personally identifiable information from anyone under the age of 13. If You are a parent or guardian and You are aware that Your child has provided Us with Personal Data, please contact Us. If We become aware that We have collected Personal Data from anyone under the age of 13 without verification of parental consent, We take steps to remove that information from Our servers.\n\n'
                  'If We need to rely on consent as a legal basis for processing Your information and Your country requires consent from a parent, We may require Your parent\'s consent before We collect and use that information.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Links to Other Websites',
              content:
                  'Our Service may contain links to other websites that are not operated by Us. If You click on a third party link, You will be directed to that third party\'s site. We strongly advise You to review the Privacy Policy of every site You visit.\n\n'
                  'We have no control over and assume no responsibility for the content, privacy policies or practices of any third party sites or services.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Changes to this Privacy Policy',
              content:
                  'We may update Our Privacy Policy from time to time. We will notify You of any changes by posting the new Privacy Policy on this page.\n\n'
                  'We will let You know via email and/or a prominent notice on Our Service, prior to the change becoming effective and update the "Last updated" date at the top of this Privacy Policy.\n\n'
                  'You are advised to review this Privacy Policy periodically for any changes. Changes to this Privacy Policy are effective when they are posted on this page.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Contact Us',
              content: 'If you have any questions about this Privacy Policy, You can contact us:',
              children: [
                TextButton(
                  onPressed: () => _launchUrl('https://telabs.co.tz'),                  
                  child: 
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'By visiting this page on our website: ',
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.normal
                            ),
                          ),
                          TextSpan(
                            text: 'https://telabs.co.tz',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.normal
                            ),
                          ),
                        ]
                      )
                    ),
                ),

                TextButton(
                  onPressed: () => _launchPhoneCall(context, '+255 766 032 160'),                  
                  child: 
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'By phone call: ',
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.normal
                            ),
                          ),
                          TextSpan(
                            text: '+255 766 032 160',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.normal
                            ),
                          ),
                        ]
                      )
                    ),
                ),

                TextButton(
                  onPressed: () => _launchEmailApp(
                    context,
                    recipient: 'tiketimkononi@telabs.co.tz',
                    subject: 'Tiketi_Mkononi',
                    body: '',
                  ),                  
                  child: 
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'By email: ',
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.black,
                              fontWeight: FontWeight.normal
                            ),
                          ),
                          TextSpan(
                            text: 'tiketimkononi@telabs.co.tz',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.blue,
                              fontWeight: FontWeight.normal
                            ),
                          ),
                        ]
                      )
                    ),
                )




              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _launchPhoneCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone app')),
      );
    }
  }

  Future<void> _launchEmailApp(BuildContext context, { required String recipient, String? subject, String? body}) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: recipient,
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      },
    );

    try {
      await launchUrl(
        launchUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch email: $e')),
      );
    }
  }

  Widget _buildSection({
    required String title,
    String? content,
    List<Widget>? children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (content != null)
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
        if (children != null) ...children,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSubSection({
    required String title,
    String? content,
    String? additionalContent,
    List<Widget>? children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (content != null)
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
        if (children != null) ...children,
        if (additionalContent != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              additionalContent,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefinitionItem({
    required String term,
    required String definition,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• $term: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              definition,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(
    String text, {
    bool isLink = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: isLink ? Colors.blue : null,
                  decoration: isLink ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
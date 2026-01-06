import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/models/user_profile.dart';

class UserInformationPage extends StatelessWidget {
  final UserProfile user;

  const UserInformationPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'User Information',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        foregroundColor: Colors.black,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildProfileHeader(),
              _buildUserInfoCard(),
              _buildContactCard(),
              _buildAddressCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.orange[800],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange[900]!.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Image
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: user.imageUrl != null && user.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.network(
                      user.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAvatar();
                      },
                    ),
                  )
                : _buildDefaultAvatar(),
          ),
          
          const SizedBox(height: 16),
          
          // User Name
          Text(
            '${user.firstName} ${user.middleName.isNotEmpty ? '${user.middleName} ' : ''}${user.lastName}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // User Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _getRoleColor(),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue[200],
      ),
      child: Icon(
        Icons.person,
        size: 60,
        color: Colors.blue[800],
      ),
    );
  }

  Color _getRoleColor() {
    switch (user.role.toLowerCase()) {
      case 'admin':
        return Colors.red[400]!;
      case 'manager':
        return Colors.orange[400]!;
      case 'user':
        return Colors.green[400]!;
      default:
        return Colors.blue[400]!;
    }
  }

  Widget _buildUserInfoCard() {
    return _buildCard(
      title: 'Personal Information',
      icon: Icons.person_outline,
      children: [
        _buildInfoRow(
          label: 'User ID',
          value: user.id.toString(),
          icon: Icons.badge_outlined,
        ),
        _buildInfoRow(
          label: 'Full Name',
          value: '${user.firstName} ${user.middleName} ${user.lastName}',
          icon: Icons.person,
        ),
        _buildInfoRow(
          label: 'Role',
          value: user.role,
          icon: Icons.work_outline,
          valueColor: _getRoleColor(),
        ),
      ],
    );
  }

  Widget _buildContactCard() {
    return _buildCard(
      title: 'Contact Information',
      icon: Icons.contact_mail_outlined,
      children: [
        _buildInfoRow(
          label: 'Email',
          value: user.email,
          icon: Icons.email_outlined,
          isEmail: true,
        ),
        _buildInfoRow(
          label: 'Phone',
          value: user.phoneNumber,
          icon: Icons.phone_outlined,
          isPhone: true,
        ),
      ],
    );
  }

  Widget _buildAddressCard() {
    return _buildCard(
      title: 'Address Information',
      icon: Icons.location_on_outlined,
      children: [
        _buildInfoRow(
          label: 'Region',
          value: user.region,
          icon: Icons.location_city_outlined,
        ),
        _buildInfoRow(
          label: 'District',
          value: user.district,
          icon: Icons.location_city_outlined,
        ),
        _buildInfoRow(
          label: 'Ward',
          value: user.ward,
          icon: Icons.account_balance_outlined,
        ),
        _buildInfoRow(
          label: 'Street',
          value: user.street,
          icon: Icons.home_outlined,
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.blue[700],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Divider
            Divider(
              color: Colors.grey[200],
              height: 1,
              thickness: 1,
            ),
            
            const SizedBox(height: 16),
            
            // Info Items
            Column(
              children: children,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
    bool isEmail = false,
    bool isPhone = false,
    bool copyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Colors.blue[700],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Label and Value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: copyable
                            ? () {
                                // You can implement copy to clipboard here
                                // ScaffoldMessenger.of(context).showSnackBar(
                                //   SnackBar(content: Text('Copied to clipboard')),
                                // );
                              }
                            : null,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: valueColor ?? Colors.grey[800],
                          ),
                        ),
                      ),
                    ),
                    if (isEmail)
                      IconButton(
                        icon: Icon(
                          Icons.email_outlined,
                          size: 18,
                          color: Colors.blue[600],
                        ),
                        onPressed: () {
                          // Implement email action
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    if (isPhone)
                      IconButton(
                        icon: Icon(
                          Icons.phone_outlined,
                          size: 18,
                          color: Colors.blue[600],
                        ),
                        onPressed: () {
                          // Implement phone action
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    if (copyable)
                      IconButton(
                        icon: Icon(
                          Icons.copy_outlined,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                        onPressed: () {
                          // Implement copy to clipboard
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
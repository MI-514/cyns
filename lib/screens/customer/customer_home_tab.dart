import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/category_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/location_provider.dart';

import 'worker_list_screen.dart';

class CustomerHomeTab extends StatefulWidget {
  const CustomerHomeTab({super.key});

  @override
  State<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

class _CustomerHomeTabState extends State<CustomerHomeTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _getFirstName(AuthProvider auth) {
    String full = auth.userModel?.fullName.trim() ?? '';
    if (full.isNotEmpty) {
      return full.split(' ').first;
    }
    String email = auth.userModel?.email.trim() ?? '';
    if (email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Customer';
  }

  IconData _getCategoryIcon(String name) {
    String lower = name.toLowerCase();
    if (lower.contains('plumb')) {
      return Icons.plumbing_rounded;
    }
    if (lower.contains('electr')) {
      return Icons.electric_bolt_rounded;
    }
    if (lower.contains('mechan') || lower.contains('auto')) {
      return Icons.car_repair_rounded;
    }
    if (lower.contains('paint')) {
      return Icons.format_paint_rounded;
    }
    if (lower.contains('carpenter') || lower.contains('wood')) {
      return Icons.carpenter_rounded;
    }
    if (lower.contains('clean')) {
      return Icons.cleaning_services_rounded;
    }
    if (lower.contains('ac') || lower.contains('appliance')) {
      return Icons.ac_unit_rounded;
    }
    if (lower.contains('tech') || lower.contains('repair')) {
      return Icons.build_rounded;
    }
    return Icons.handyman_rounded;
  }

  Color _getCategoryColor(int index) {
    List<Color> colors = [
      const Color(0xFF2563EB), // Royal Blue
      const Color(0xFF0D9488), // Teal
      const Color(0xFFD97706), // Amber
      const Color(0xFF7C3AED), // Purple
      const Color(0xFF059669), // Emerald
      const Color(0xFFDC2626), // Red
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final location = Provider.of<LocationProvider>(context);

    // Filter categories based on search input
    List<CategoryModel> displayedCategories = categoryProvider.categories;
    if (_searchQuery.trim().isNotEmpty) {
      String query = _searchQuery.toLowerCase().trim();
      displayedCategories = displayedCategories.where((cat) {
        return cat.name.toLowerCase().contains(query) ||
            cat.description.toLowerCase().contains(query);
      }).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header displaying Customer Greeting & Location Chip
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.primaryNavy,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.pureWhite,
                  child: Text(
                    _getFirstName(auth).isNotEmpty
                        ? _getFirstName(auth)[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${_getFirstName(auth)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryNavy,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: AppColors.accentBlue,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location.currentAddress.isNotEmpty
                                ? location.currentAddress
                                : 'Fetching location...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Bar for Categories
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryNavy.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search service categories (Plumber, Electrician...)',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.primaryNavy),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Dispatch Promo Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.primaryNavy,
                  AppColors.lightNavy,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryNavy.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.starGold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'INSTANT DISPATCH',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Need urgent repairs at home?',
                        style: TextStyle(
                          color: AppColors.pureWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap any category below to auto-dispatch nearest available worker.',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.near_me_rounded,
                    color: AppColors.pureWhite,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Service Categories Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Service Categories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${displayedCategories.length} Categories',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryNavy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Categories Grid View
          categoryProvider.isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : displayedCategories.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.pureWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.dividerColor),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 48, color: AppColors.textLight),
                          SizedBox(height: 8),
                          Text(
                            'No matching service categories found.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        double screenWidth = constraints.maxWidth;
                        int crossAxisCount = screenWidth > 600 ? 3 : 2;
                        double childAspectRatio =
                            screenWidth > 360 ? 1.02 : 0.92;

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayedCategories.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemBuilder: (context, index) {
                            final cat = displayedCategories[index];
                            final catColor = _getCategoryColor(index);
                            final catIcon = _getCategoryIcon(cat.name);

                            return Card(
                              elevation: 3,
                              shadowColor: const Color(0x0C0F172A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: const BorderSide(
                                  color: AppColors.dividerColor,
                                  width: 1.0,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          WorkerListScreen(
                                        selectedCategoryId: cat.id,
                                        categoryName: cat.name,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color:
                                              catColor.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Icon(
                                          catIcon,
                                          color: catColor,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        cat.name,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryNavy,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        cat.description,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'CYN – Chase Your Needs';
  static const String appTagline = 'Connect with Skilled Workers Near You';

  // Global Keys for safe app-wide contextless navigation & snackbars
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // Role Constants (Customer / Employer & Worker / Service Provider)
  static const String roleCustomer = 'customer';
  static const String roleWorker = 'worker';

  // Request Statuses
  static const String statusPending = 'Pending';
  static const String statusAccepted = 'Accepted';
  static const String statusRejected = 'Rejected';
  static const String statusCancelled = 'Cancelled';
  static const String statusMissed = 'Missed';
  static const String statusOnTheWay = 'On the Way';
  static const String statusArrived = 'Arrived';
  static const String statusInProgress = 'In Progress';
  static const String statusCompleted = 'Completed';

  // Timeout for worker to accept a job offer (in seconds)
  static const int requestTimeoutSeconds = 60;

  // Default Categories
  static const List<Map<String, String>> defaultCategories = [
    {
      'id': 'plumber',
      'name': 'Plumber',
      'description':
          'Water leakages, pipe repairs, tap installation & drainage solutions.',
      'icon': 'plumbing',
    },
    {
      'id': 'electrician',
      'name': 'Electrician',
      'description':
          'Wiring, short circuits, switchboard repair & light installation.',
      'icon': 'electrical_services',
    },
    {
      'id': 'carpenter',
      'name': 'Carpenter',
      'description': 'Furniture repair, door fitting, locks & woodwork.',
      'icon': 'carpenter',
    },
    {
      'id': 'auto_mechanic',
      'name': 'Auto Mechanic',
      'description': 'Car & bike repair, engine breakdown & roadside support.',
      'icon': 'build',
    },
    {
      'id': 'painter',
      'name': 'Painter',
      'description':
          'Interior & exterior wall painting, touch-ups & polishing.',
      'icon': 'format_paint',
    },
    {
      'id': 'mason',
      'name': 'Mason',
      'description': 'Brickwork, concrete repairs & construction labor.',
      'icon': 'foundation',
    },
    {
      'id': 'laborer',
      'name': 'Laborer',
      'description': 'General manual labor, loading/unloading & heavy lifting.',
      'icon': 'engineering',
    },
    {
      'id': 'ac_technician',
      'name': 'AC Technician',
      'description': 'Air conditioner installation, servicing & gas refilling.',
      'icon': 'ac_unit',
    },
    {
      'id': 'refrigerator_technician',
      'name': 'Refrigerator Technician',
      'description':
          'Fridge cooling repair, gas leak repair & thermostat replacement.',
      'icon': 'kitchen',
    },
    {
      'id': 'washing_machine_technician',
      'name': 'Washing Machine Technician',
      'description':
          'Automatic & semi-automatic machine repair & drum service.',
      'icon': 'local_laundry_service',
    },
    {
      'id': 'computer_technician',
      'name': 'Mobile/Computer Technician',
      'description':
          'Laptop, PC & smartphone hardware and software troubleshooting.',
      'icon': 'devices',
    },
    {
      'id': 'appliance_repair',
      'name': 'Appliance Repair',
      'description':
          'Microwave, oven, water heater & general home electronics.',
      'icon': 'home_repair_service',
    },
    {
      'id': 'welder',
      'name': 'Welder',
      'description': 'Iron gate, steel grill & structural metal welding.',
      'icon': 'handyman',
    },
    {
      'id': 'tile_worker',
      'name': 'Tile Worker',
      'description': 'Floor tiling, wall tiles, marble fitting & grouting.',
      'icon': 'grid_view',
    },
  ];
}

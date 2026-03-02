import 'package:flutter/material.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black, size: 16),
        onPressed: () {},
      ),
      title: Text(
        'Activity',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(5),
            maximumSize: Size(30, 30),
            minimumSize: Size(30, 30),
            shape: CircleBorder(),
            backgroundColor: Color(0xffffe6da), // Background color
            foregroundColor: Color(0xfffa7a3b), // Icon color
          ),
          child: Icon(Icons.notifications, size: 16),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

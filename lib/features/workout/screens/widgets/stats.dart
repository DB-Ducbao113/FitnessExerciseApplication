import 'package:flutter/material.dart';

class Stats extends StatelessWidget {
  const Stats({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            children: [
              Text(
                'Workout Stats',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              Icon(Icons.pie_chart_rounded, size: 15, color: Color(0xff3bc6fa)),
            ],
          ),
        ),
        SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(width: 30),
              InfoStat(
                icon: Icons.timer,
                iconColor: Color(0xff535bed),
                iconBackground: Color(0xffe4e7ff),
                time: '+5s',
                label: 'Time',
                value: '30:34',
              ),
              SizedBox(width: 15),
              InfoStat(
                icon: Icons.favorite_outline,
                iconColor: Color(0xffe11e6c),
                iconBackground: Color(0xffffe4fb),
                time: '+5s',
                label: 'Heart Rate',
                value: '151bpm',
              ),
              SizedBox(width: 15),
              InfoStat(
                icon: Icons.bolt,
                iconColor: Color(0xffd3b50f),
                iconBackground: Color(0xfffb4be4),
                time: '+5s',
                label: 'Energy',
                value: '160kcal',
              ),
              SizedBox(width: 30),
            ],
          ),
        ),
      ],
    );
  }
}

class InfoStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String time;
  final String value;
  final String label;

  const InfoStat({
    super.key,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.label,
    required this.time,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      width: 110,
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Color(0xffe1e1e1)),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 3),
        ],
      ),
      child: Stack(
        children: [
          StatIcon(
            icon: icon,
            iconColor: iconColor,
            iconBackground: iconBackground,
          ),
          Change(time: time),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10)),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Change extends StatelessWidget {
  const Change({super.key, required this.time});

  final String time;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(500),
        ),
        child: Text(time, style: TextStyle(fontSize: 10, color: Colors.white)),
      ),
    );
  }
}

class StatIcon extends StatelessWidget {
  const StatIcon({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: iconBackground,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 15, color: iconColor),
    );
  }
}

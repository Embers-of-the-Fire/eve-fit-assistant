import 'package:flutter/material.dart';

class FunctionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double? height;
  final EdgeInsets? margin;
  final void Function()? onTap;
  final Color color;

  const FunctionCard({
    super.key,
    this.onTap,
    required this.icon,
    required this.title,
    this.margin,
    this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
      margin: margin,
      height: height,
      child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: const Color(0xFF0D0D0D),
                    border: Border.all(color: color.withAlpha(76), width: 1),
                    boxShadow: [
                      BoxShadow(
                          color: color.withAlpha(25),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                          right: -20,
                          bottom: -20,
                          child: Transform.rotate(
                              angle: -0.4,
                              child: Container(
                                width: 60,
                                height: 2,
                                color: color.withAlpha(127),
                              ))),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(icon, color: color, size: 32),
                          const Spacer(),
                          Text(title,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'Orbitron',
                                  color: color,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          Container(height: 2, color: color.withAlpha(127)),
                        ]),
                      ),

                      // 状态指示器
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withAlpha(204),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                ),
                              ],
                            )),
                      )
                    ],
                  )))));
}

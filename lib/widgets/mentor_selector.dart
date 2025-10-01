import 'package:flutter/material.dart';
import '../models/mentor.dart';
import '../design/glass.dart';

class MentorSelector extends StatefulWidget {
  final Mentor selectedMentor;
  final Function(Mentor) onMentorChanged;

  const MentorSelector({
    super.key,
    required this.selectedMentor,
    required this.onMentorChanged,
  });

  @override
  State<MentorSelector> createState() => _MentorSelectorState();
}

class _MentorSelectorState extends State<MentorSelector> with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120, // Increased height to accommodate names
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: LegendaryMentors.all.map((mentor) {
          final isSelected = mentor.id == widget.selectedMentor.id;
          
          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                widget.onMentorChanged(mentor);
                _showMentorTransition(mentor);
              }
            },
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                                color: mentor.primaryColor.withValues(alpha: _glowAnimation.value),
                            width: 3,
                          )
                        : Border.all(
                                color: Colors.grey.withValues(alpha: 0.3),
                            width: 1,
                          ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                  color: mentor.primaryColor.withValues(alpha: _glowAnimation.value * 0.5),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipOval(
                        child: Center(
                          child: Image.asset(
                            mentor.avatarAsset,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            alignment: Alignment(0.0, -0.2), // Move faces down slightly
                            errorBuilder: (context, error, stackTrace) {
                            // Fallback to gradient if image fails to load
                            return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                mentor.primaryColor,
                                mentor.accentColor,
                              ],
                            ),
                          ),
                              child: Center(
                          child: Text(
                            mentor.name[0],
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                        color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                            );
                          },
                              ),
                            ),
                          ),
                          ),
                    const SizedBox(height: 4),
                    Text(
                      mentor.name,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showMentorTransition(Mentor mentor) {
    // Simple snackbar instead of dialog to prevent crashes
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${mentor.name} has joined you. ${mentor.signature}'),
        duration: const Duration(milliseconds: 2000),
        backgroundColor: mentor.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}


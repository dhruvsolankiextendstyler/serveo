import 'package:flutter/material.dart';

class ServeoAppBar extends StatelessWidget implements PreferredSizeWidget{
  final String title;
  const ServeoAppBar({super.key, this.title = "Serveo"});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black,
      title: Row(
        children: [
          Icon(Icons.fastfood_outlined),
          SizedBox(width:10),
          Text(title),
        ],
      ),
    );
  }

  @override
  // TODO: implement preferredSize
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

typedef BreakBiteAppBar = ServeoAppBar;
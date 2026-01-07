import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// IMPORT
import '../data/repositories/content_repository.dart'; 
import '../logic/content/content_cubit.dart'; 
import '../logic/content/content_state.dart'; 
import '../data/models/content_model.dart'; 

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ContentCubit(context.read<ContentRepository>())..fetchContent(),
      
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "Home",
            style: TextStyle(
              color: Color(0xFFA01C1C),
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // --- HEADER (SEARCH & FILTER) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildSearchBar(), // Renamed to lowerCamelCase
                  const SizedBox(height: 15),
                  _buildCategoryFilter(), // Renamed to lowerCamelCase
                ],
              ),
            ),
            const SizedBox(height: 10),

            // --- LIST KONTEN ---
            Expanded(
              child: BlocBuilder<ContentCubit, ContentState>(
                builder: (context, state) {
                  if (state is ContentLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is ContentError) {
                    return Center(child: Text(state.message));
                  } else if (state is ContentLoaded) {
                    if (state.displayList.isEmpty) {
                      return const Center(child: Text("Data tidak ditemukan"));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: state.displayList.length,
                      itemBuilder: (context, index) {
                        final item = state.displayList[index];
                        return _buildMenuItem(context, item);
                      },
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET SEARCH BAR ---
  // Renamed from _SearchBar to _buildSearchBar
  Widget _buildSearchBar() {
    return Builder(
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: TextField(
            onChanged: (value) {
              context.read<ContentCubit>().filterContent(query: value);
            },
            decoration: const InputDecoration(
              hintText: "Search...",
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        );
      }
    );
  }

  // --- WIDGET CATEGORY CHIPS ---
  // Renamed from _CategoryFilter to _buildCategoryFilter
  Widget _buildCategoryFilter() {
    return BlocBuilder<ContentCubit, ContentState>(
      builder: (context, state) {
        String activeCategory = "All";
        if (state is ContentLoaded) {
          activeCategory = state.activeCategory;
        }

        final categories = ["All", "Ihram", "Thawaf", "Sa'i", "Tahallul"];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isActive = activeCategory == cat;
              return GestureDetector(
                onTap: () {
                  context.read<ContentCubit>().filterContent(category: cat);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? const Color(0xFFA01C1C) : Colors.grey.shade300,
                      width: 1,
                    ),
                    boxShadow: isActive ? [
                        BoxShadow(
                        // FIXED: Replaced withOpacity with withValues(alpha: ...)
                        color: Colors.red.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2)
                      )
                    ] : [],
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isActive ? const Color(0xFFA01C1C) : Colors.black87,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(BuildContext context, ContentModel item) {
    return GestureDetector(
      onTap: () {
        _showDetailModal(context, item);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          item.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  void _showDetailModal(BuildContext context, ContentModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7, 
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA01C1C),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    item.arabic,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    item.latin,
                    style: const TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Terjemahan:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.translateId,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if(item.description.isNotEmpty)...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: Text(
                          item.description,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      )
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }
}
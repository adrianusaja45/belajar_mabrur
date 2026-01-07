import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/auth_repository.dart';
import '../bloc/content_cubit.dart';
import '../models/content_model.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Bungkus dengan BlocProvider agar Cubit bisa jalan
    return BlocProvider(
      create: (context) => ContentCubit(context.read<AuthRepository>())..fetchContent(),
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
                  // 1. Search Bar
                  _SearchBar(),
                  const SizedBox(height: 15),
                  // 2. Filter Chips
                  _CategoryFilter(),
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
                    // Tampilkan List
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
  Widget _SearchBar() {
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
              // Panggil cubit untuk filter search
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
  Widget _CategoryFilter() {
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
                        color: Colors.red.withOpacity(0.1),
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

  // --- WIDGET LIST ITEM (CARD) ---
  Widget _buildMenuItem(BuildContext context, ContentModel item) {
    return GestureDetector(
      onTap: () {
        // Tampilkan Detail Modal saat diklik (Seperti di video)
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

  // --- DETAIL MODAL (POPUP BAWAH) ---
  void _showDetailModal(BuildContext context, ContentModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Agar bisa full screen jika konten panjang
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7, // Tinggi awal 70% layar
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
                  // Garis kecil handle
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

                  // Judul
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA01C1C),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Arab
                  Text(
                    item.arabic,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri', // Pastikan font support Arab jika ada
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Latin
                  Text(
                    item.latin,
                    style: const TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Terjemahan
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
                  // Deskripsi (Optional)
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
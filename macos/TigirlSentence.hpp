#pragma once
#include <filesystem>
#include <memory>
#include <string>

namespace tiger { class SentenceResources; }

// Shared, immutable sentence resources (fivegram model + sentence lexicon),
// cached per dictionary path. Loaded on a background queue and borrowed by all
// input controllers; the 405 MB model is mapped once.
std::shared_ptr<const tiger::SentenceResources> TigirlSentenceResources(const std::string& dictionaryPath);
void TigirlLoadSentenceResources(std::filesystem::path dictionary);

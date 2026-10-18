#include "LexiconDirectory.h"
#include "LexiconPublish.h"
#include "SentenceImport.h"
#include "LexiconDecode.h"
#include "Dictionary.h"
#include <filesystem>
#include <iostream>

int main(int argc, char **argv) {
    try {
        if (argc != 4 && argc != 5) {
            std::cerr << "usage: TigirlLexiconImport <schema-dir> <pinyin-dir> <output.tcd> [supplement.txt]\n";
            return 2;
        }
        const std::filesystem::path schema = argv[1], pinyin = argv[2], output = argv[3];
        if (!std::filesystem::is_directory(schema) || !std::filesystem::is_directory(pinyin))
            throw std::runtime_error("schema and pinyin paths must be directories");
        auto imported = tiger::importLexiconDirectory(schema, pinyin, "zh-CN");
        std::filesystem::path supplement = argc == 5 ? std::filesystem::path(argv[4])
                                                     : schema / "补充语料.txt";
        const auto supplementText = std::filesystem::is_regular_file(supplement)
            ? tiger::readLexiconText(supplement) : std::u16string{};
        tiger::publishSentenceSidecars(imported, supplementText, output);
        tiger::publishImportedLexicon(imported, output);
        auto check = tiger::Dictionary::Open(output);
        std::cout << "generated " << output << " (" << check->mappedBytes() << " bytes)\n";
        return 0;
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}

#include "TigirlSentence.hpp"
#include "SentenceResources.h"

#include <dispatch/dispatch.h>
#include <map>
#include <mutex>
#include <set>

static std::mutex gSentenceMutex;
static std::map<std::string, std::shared_ptr<const tiger::SentenceResources>> gSentenceCache;
static std::set<std::string> gSentenceLoading;

std::shared_ptr<const tiger::SentenceResources> TigirlSentenceResources(const std::string& dictionaryPath) {
    std::lock_guard<std::mutex> lock(gSentenceMutex);
    auto found = gSentenceCache.find(dictionaryPath);
    return found == gSentenceCache.end() ? nullptr : found->second;
}

void TigirlLoadSentenceResources(std::filesystem::path dictionary) {
    const std::string key = dictionary.string();
    {
        std::lock_guard<std::mutex> lock(gSentenceMutex);
        if (gSentenceCache.count(key) || gSentenceLoading.count(key)) return;
        gSentenceLoading.insert(key);
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        const auto model = dictionary.parent_path() / "Models" / "sentence-fivegram-mobile.bin";
        if (!std::filesystem::is_regular_file(model)) {
            std::lock_guard<std::mutex> lock(gSentenceMutex);
            gSentenceLoading.erase(key);
            return;
        }
        tiger::SentenceDecoderOptions options;
        options.emittedCharacterReward = 2;
        options.wholeInputSingleCharacterReward = 5;
        options.lexicalPriorWeight = .1;
        options.lexicalCandidateLimit = 5;
        options.autoSelectMinCodeLength = 3;
        options.preserveTruncatedEarlyCommitEvidence = true;
        std::shared_ptr<const tiger::SentenceResources> resources;
        try {
            resources = tiger::SentenceResources::Open(dictionary, model, 1500, {}, options);
        } catch (...) {
        }
        std::lock_guard<std::mutex> lock(gSentenceMutex);
        gSentenceLoading.erase(key);
        if (resources) gSentenceCache[key] = std::move(resources);
    });
}

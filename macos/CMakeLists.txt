cmake_minimum_required(VERSION 3.25)
project(TigirlMacOS LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 20)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

if(NOT APPLE)
  message(FATAL_ERROR "TigirlMacOS requires macOS and InputMethodKit")
endif()

set(TIGIRL_ROOT "${CMAKE_CURRENT_LIST_DIR}/..")
set(TIGIRL_DICTIONARY "${TIGIRL_ROOT}/build/ARM64/Release/tiger-v2.tcd" CACHE FILEPATH "Bundled Tigirl native dictionary")
set(TIGIRL_SENTENCE_DICTIONARY "${TIGIRL_ROOT}/build/ARM64/Release/tiger-v2-sentence.tcd" CACHE FILEPATH "Bundled sentence-schema dictionary")
set(TIGIRL_SENTENCE_MODEL "${TIGIRL_ROOT}/data/Models/sentence-fivegram-mobile.bin" CACHE FILEPATH "Tigirl fivegram sentence model")
set(TIGIRL_SENTENCE_LEXICAL "${TIGIRL_ROOT}/resources/sentence-lexical-v1.bin" CACHE FILEPATH "Tigirl sentence lexical prior")

# Keep the macOS adapter separate from the Windows TSF target. The source list
# is deliberately explicit so platform-only files cannot leak into the core.
set(TIGIRL_CORE_SOURCES
  ${TIGIRL_ROOT}/native/Engine.cpp
  ${TIGIRL_ROOT}/native/Lexicon.cpp
  ${TIGIRL_ROOT}/native/Dictionary.cpp
  ${TIGIRL_ROOT}/native/DynamicText.cpp
  ${TIGIRL_ROOT}/native/Text.cpp
  ${TIGIRL_ROOT}/native/UppercaseText.cpp
  ${TIGIRL_ROOT}/native/SentenceAutoCommit.cpp
  ${TIGIRL_ROOT}/native/SentenceSession.cpp
  ${TIGIRL_ROOT}/native/SentenceDecoder.cpp
  ${TIGIRL_ROOT}/native/SentenceLexicon.cpp
  ${TIGIRL_ROOT}/native/SentenceNgram.cpp
  ${TIGIRL_ROOT}/native/SentenceFivegram.cpp
  ${TIGIRL_ROOT}/native/SentenceCharacterRanks.cpp
  ${TIGIRL_ROOT}/native/SentenceResources.cpp
  ${TIGIRL_ROOT}/native/SentenceImport.cpp
  ${TIGIRL_ROOT}/native/SentenceRebuild.cpp
  ${TIGIRL_ROOT}/native/AddWord.cpp
  ${TIGIRL_ROOT}/native/LexiconPublish.cpp
  ${TIGIRL_ROOT}/native/LexiconSerialize.cpp
  ${TIGIRL_ROOT}/native/LexiconOrder.cpp
)

add_library(TigirlCore STATIC ${TIGIRL_CORE_SOURCES})
target_include_directories(TigirlCore PUBLIC ${TIGIRL_ROOT}/native)
target_compile_definitions(TigirlCore PUBLIC TIGIRL_MACOS=1)
target_compile_options(TigirlCore PRIVATE -Wall -Wextra -Wpedantic)

add_executable(TigirlInputMethod
  TigirlInputController.mm
  TigirlInputMethod.mm
  TigirlCandidateWindow.mm
  TigirlKeyMap.mm
  TigirlSentence.mm
)

add_executable(TigirlLexiconImport
  lexicon_import_main.cpp
  ${TIGIRL_ROOT}/native/Dictionary.cpp
  ${TIGIRL_ROOT}/native/LexiconDecode.cpp
  ${TIGIRL_ROOT}/native/LexiconFile.cpp
  ${TIGIRL_ROOT}/native/LexiconImport.cpp
  ${TIGIRL_ROOT}/native/AddWord.cpp
  ${TIGIRL_ROOT}/native/LexiconOrder.cpp
  ${TIGIRL_ROOT}/native/LexiconDirectory.cpp
  ${TIGIRL_ROOT}/native/LexiconSerialize.cpp
  ${TIGIRL_ROOT}/native/LexiconPublish.cpp
  ${TIGIRL_ROOT}/native/SentenceImport.cpp
  ${TIGIRL_ROOT}/native/SentenceLexicon.cpp
  ${TIGIRL_ROOT}/native/Text.cpp
)
target_include_directories(TigirlLexiconImport PRIVATE ${TIGIRL_ROOT}/native)
target_compile_definitions(TigirlLexiconImport PRIVATE TIGIRL_MACOS=1)
target_include_directories(TigirlInputMethod PRIVATE ${TIGIRL_ROOT}/native ${CMAKE_CURRENT_LIST_DIR})
target_link_libraries(TigirlInputMethod PRIVATE TigirlCore
  "-framework InputMethodKit"
  "-framework Cocoa"
  "-framework Carbon"
)
set_target_properties(TigirlInputMethod PROPERTIES
  MACOSX_BUNDLE TRUE
  BUNDLE_EXTENSION app
  OUTPUT_NAME TigirlInputMethod
  MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_LIST_DIR}/Info.plist
  XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER com.viui.inputmethod.Tigirl
  XCODE_ATTRIBUTE_PRODUCT_NAME TigirlInputMethod
)
if(EXISTS "${TIGIRL_DICTIONARY}")
  set_source_files_properties("${TIGIRL_DICTIONARY}" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
  target_sources(TigirlInputMethod PRIVATE "${TIGIRL_DICTIONARY}")
  foreach(sidecar ".sentence.tcd" ".supplement.tcd")
    set(path "${TIGIRL_DICTIONARY}${sidecar}")
    if(EXISTS "${path}")
      set_source_files_properties("${path}" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
      target_sources(TigirlInputMethod PRIVATE "${path}")
    endif()
  endforeach()
endif()
if(EXISTS "${TIGIRL_SENTENCE_DICTIONARY}")
  set_source_files_properties("${TIGIRL_SENTENCE_DICTIONARY}" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
  target_sources(TigirlInputMethod PRIVATE "${TIGIRL_SENTENCE_DICTIONARY}")
  foreach(sidecar ".sentence.tcd" ".supplement.tcd")
    set(path "${TIGIRL_SENTENCE_DICTIONARY}${sidecar}")
    if(EXISTS "${path}")
      set_source_files_properties("${path}" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
      target_sources(TigirlInputMethod PRIVATE "${path}")
    endif()
  endforeach()
endif()
if(EXISTS "${TIGIRL_SENTENCE_MODEL}")
  set_source_files_properties("${TIGIRL_SENTENCE_MODEL}" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources/Models")
  target_sources(TigirlInputMethod PRIVATE "${TIGIRL_SENTENCE_MODEL}")
endif()
if(EXISTS "${TIGIRL_SENTENCE_LEXICAL}")
  set_source_files_properties("${TIGIRL_SENTENCE_LEXICAL}" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources/Models")
  target_sources(TigirlInputMethod PRIVATE "${TIGIRL_SENTENCE_LEXICAL}")
endif()
if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/Tigirl.tiff")
  set_source_files_properties("${CMAKE_CURRENT_LIST_DIR}/Tigirl.tiff" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
  target_sources(TigirlInputMethod PRIVATE "${CMAKE_CURRENT_LIST_DIR}/Tigirl.tiff")
endif()
if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/Tigirl.pdf")
  set_source_files_properties("${CMAKE_CURRENT_LIST_DIR}/Tigirl.pdf" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
  target_sources(TigirlInputMethod PRIVATE "${CMAKE_CURRENT_LIST_DIR}/Tigirl.pdf")
endif()
if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/Tigirl.icns")
  set_source_files_properties("${CMAKE_CURRENT_LIST_DIR}/Tigirl.icns" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
  target_sources(TigirlInputMethod PRIVATE "${CMAKE_CURRENT_LIST_DIR}/Tigirl.icns")
endif()
foreach(lang en zh-Hans)
  set(lproj_strings "${CMAKE_CURRENT_LIST_DIR}/${lang}.lproj/InfoPlist.strings")
  if(EXISTS "${lproj_strings}")
    set_source_files_properties("${lproj_strings}" PROPERTIES MACOSX_PACKAGE_LOCATION "Resources/${lang}.lproj")
    target_sources(TigirlInputMethod PRIVATE "${lproj_strings}")
  endif()
endforeach()

install(TARGETS TigirlInputMethod
  BUNDLE DESTINATION "Library/Input Methods"
  LIBRARY DESTINATION "Library/Input Methods"
)
install(TARGETS TigirlLexiconImport RUNTIME DESTINATION bin)

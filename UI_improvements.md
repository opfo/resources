# UI Improvements
Possible improvements to increase user experience. Collect stuff here so we don't forget about it.

## Bugs
*Everything in UI that obviously shouldn't be like this.  Most of them must be fixed*
### Optical

- Cells in Questions View don't align with height of content. Espacially tags may extend to next cell.
- Bio in Users view does not correctly align with content
- Body / Tag cell in Single Question View doesn't align with height of content, may result in clipping or overboarding
- Wrong gravatars displayed while scrolling in User search view
- URL in User search preview cells may intersect with upvote label
- Some post bodys don't get rendered (displaying Loading…)

### Navigational

- Tapping on Tags in Questions View mistakly opens the question
- Some comments scroll on their own 
  (When to use volatile to counteract compiler optimizations in C# > 3rd comment on Question)
- No way to get back to own profile after tapping on questions in My Profile Tab. Same for every profile in Users Tab.
- Tapping on Questions in a User profile takes shitload of time and doesn't seem to work

## Not finished
*Missing or incomplete data. Interfaces that look unfinished. Missing connections between views. Should be finished or*
### Optical

- Up / Downvote in content
- Background in Questions View
- The whole Singe Question View (unclear what data means)
    - No accepted answer mark in Single Question View
    - No date / time of question
    - Headers for answers are pretty empty. Maybe remove it?
- Date / Time in comments always show 07-12-2011 00:00
- Gravatar in User Profile View overboards rounded corner
- Few result in User search list lead to empty user preview cells.

## Inconsitency
*UI Stuff that is solved differently throughout the app. One solution should be used unless there are reasons for doing it differently*
### Optical

- Gravatars are sometimes with gloss
- Comments View does not display Title. *Comments* would be consistent
- HTML content from the database is rendered differntly in the app
- Different representations of Tags

### Navigational
- Tapping on gravatar does not always open the users profile
- It should be discussed, what happens if a user navigates from one kind of view to another without using the tab bar. Does the tab change? Does tapping on a tab result in a fresh root view? Can users navigate recursivly into infinity or should the be thrown back?


## Improvements
*Could be implemented but is not necessary. Maybe a matter of taste*
### Optical

- Keep search field while scrolling
- Cache Gravatars
- Adapt font of UIWebViews to regular font to make harder to spot, that it is rendered HTML
- Accepted answer icon is pretty small

### Navigational
- Remove Keyboards in List View if user starts to scroll
- In Questions View search: Manual opening of [ or @ should start tag suggestion mode aswell. Same for closing.
- Tapping on accepted answer mark directly navigates to the accepted answer



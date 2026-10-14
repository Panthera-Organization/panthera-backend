import type { GraphQLResolveInfo } from 'graphql';
import type { ProfileRow, MembershipRow, CompanyRow } from '../rows.ts';
import type { GraphqlContext } from '../context.ts';
export type Maybe<T> = T | null;
export type InputMaybe<T> = Maybe<T>;
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };
export type MakeOptional<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]?: Maybe<T[SubKey]> };
export type MakeMaybe<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]: Maybe<T[SubKey]> };
export type MakeEmpty<T extends { [key: string]: unknown }, K extends keyof T> = { [_ in K]?: never };
export type Incremental<T> = T | { [P in keyof T]?: P extends ' $fragmentName' | '__typename' ? T[P] : never };
export type RequireFields<T, K extends keyof T> = Omit<T, K> & { [P in K]-?: NonNullable<T[P]> };
/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {
  ID: { input: string; output: string; }
  String: { input: string; output: string; }
  Boolean: { input: boolean; output: boolean; }
  Int: { input: number; output: number; }
  Float: { input: number; output: number; }
};

export type Company = {
  __typename?: 'Company';
  id: Scalars['ID']['output'];
  isPersonal: Scalars['Boolean']['output'];
  name: Scalars['String']['output'];
};

export type CreatePersonalWorkspaceInput = {
  name?: InputMaybe<Scalars['String']['input']>;
};

export type MemberRole =
  | 'ADMIN'
  | 'OWNER'
  | 'STUDENT'
  | 'TEACHER';

export type Membership = {
  __typename?: 'Membership';
  canTeach: Scalars['Boolean']['output'];
  /** Null when row policies hide the company. */
  company?: Maybe<Company>;
  id: Scalars['ID']['output'];
  role: MemberRole;
};

export type Mutation = {
  __typename?: 'Mutation';
  createPersonalWorkspace: Viewer;
  updateProfile: Viewer;
};


export type MutationCreatePersonalWorkspaceArgs = {
  input: CreatePersonalWorkspaceInput;
};


export type MutationUpdateProfileArgs = {
  input: UpdateProfileInput;
};

export type Profile = {
  __typename?: 'Profile';
  fullName: Scalars['String']['output'];
  id: Scalars['ID']['output'];
  timezone: Scalars['String']['output'];
};

export type Query = {
  __typename?: 'Query';
  viewer?: Maybe<Viewer>;
};

export type UpdateProfileInput = {
  fullName?: InputMaybe<Scalars['String']['input']>;
  timezone?: InputMaybe<Scalars['String']['input']>;
};

/** The signed-in user. Null when the bearer token is missing or invalid. */
export type Viewer = {
  __typename?: 'Viewer';
  fullName: Scalars['String']['output'];
  id: Scalars['ID']['output'];
  memberships: Array<Membership>;
  profile: Profile;
};



export type ResolverTypeWrapper<T> = Promise<T> | T;


export type ResolverWithResolve<TResult, TParent, TContext, TArgs> = {
  resolve: ResolverFn<TResult, TParent, TContext, TArgs>;
};
export type Resolver<TResult, TParent = {}, TContext = {}, TArgs = {}> = ResolverFn<TResult, TParent, TContext, TArgs> | ResolverWithResolve<TResult, TParent, TContext, TArgs>;

export type ResolverFn<TResult, TParent, TContext, TArgs> = (
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo
) => Promise<TResult> | TResult;

export type SubscriptionSubscribeFn<TResult, TParent, TContext, TArgs> = (
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo
) => AsyncIterable<TResult> | Promise<AsyncIterable<TResult>>;

export type SubscriptionResolveFn<TResult, TParent, TContext, TArgs> = (
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo
) => TResult | Promise<TResult>;

export interface SubscriptionSubscriberObject<TResult, TKey extends string, TParent, TContext, TArgs> {
  subscribe: SubscriptionSubscribeFn<{ [key in TKey]: TResult }, TParent, TContext, TArgs>;
  resolve?: SubscriptionResolveFn<TResult, { [key in TKey]: TResult }, TContext, TArgs>;
}

export interface SubscriptionResolverObject<TResult, TParent, TContext, TArgs> {
  subscribe: SubscriptionSubscribeFn<any, TParent, TContext, TArgs>;
  resolve: SubscriptionResolveFn<TResult, any, TContext, TArgs>;
}

export type SubscriptionObject<TResult, TKey extends string, TParent, TContext, TArgs> =
  | SubscriptionSubscriberObject<TResult, TKey, TParent, TContext, TArgs>
  | SubscriptionResolverObject<TResult, TParent, TContext, TArgs>;

export type SubscriptionResolver<TResult, TKey extends string, TParent = {}, TContext = {}, TArgs = {}> =
  | ((...args: any[]) => SubscriptionObject<TResult, TKey, TParent, TContext, TArgs>)
  | SubscriptionObject<TResult, TKey, TParent, TContext, TArgs>;

export type TypeResolveFn<TTypes, TParent = {}, TContext = {}> = (
  parent: TParent,
  context: TContext,
  info: GraphQLResolveInfo
) => Maybe<TTypes> | Promise<Maybe<TTypes>>;

export type IsTypeOfResolverFn<T = {}, TContext = {}> = (obj: T, context: TContext, info: GraphQLResolveInfo) => boolean | Promise<boolean>;

export type NextResolverFn<T> = () => Promise<T>;

export type DirectiveResolverFn<TResult = {}, TParent = {}, TContext = {}, TArgs = {}> = (
  next: NextResolverFn<TResult>,
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo
) => TResult | Promise<TResult>;



/** Mapping between all available schema types and the resolvers types */
export type ResolversTypes = {
  Boolean: ResolverTypeWrapper<Scalars['Boolean']['output']>;
  Company: ResolverTypeWrapper<CompanyRow>;
  CreatePersonalWorkspaceInput: CreatePersonalWorkspaceInput;
  ID: ResolverTypeWrapper<Scalars['ID']['output']>;
  MemberRole: MemberRole;
  Membership: ResolverTypeWrapper<MembershipRow>;
  Mutation: ResolverTypeWrapper<{}>;
  Profile: ResolverTypeWrapper<ProfileRow>;
  Query: ResolverTypeWrapper<{}>;
  String: ResolverTypeWrapper<Scalars['String']['output']>;
  UpdateProfileInput: UpdateProfileInput;
  Viewer: ResolverTypeWrapper<ProfileRow>;
};

/** Mapping between all available schema types and the resolvers parents */
export type ResolversParentTypes = {
  Boolean: Scalars['Boolean']['output'];
  Company: CompanyRow;
  CreatePersonalWorkspaceInput: CreatePersonalWorkspaceInput;
  ID: Scalars['ID']['output'];
  Membership: MembershipRow;
  Mutation: {};
  Profile: ProfileRow;
  Query: {};
  String: Scalars['String']['output'];
  UpdateProfileInput: UpdateProfileInput;
  Viewer: ProfileRow;
};

export type CompanyResolvers<ContextType = GraphqlContext, ParentType extends ResolversParentTypes['Company'] = ResolversParentTypes['Company']> = {
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  isPersonal?: Resolver<ResolversTypes['Boolean'], ParentType, ContextType>;
  name?: Resolver<ResolversTypes['String'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
};

export type MembershipResolvers<ContextType = GraphqlContext, ParentType extends ResolversParentTypes['Membership'] = ResolversParentTypes['Membership']> = {
  canTeach?: Resolver<ResolversTypes['Boolean'], ParentType, ContextType>;
  company?: Resolver<Maybe<ResolversTypes['Company']>, ParentType, ContextType>;
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  role?: Resolver<ResolversTypes['MemberRole'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
};

export type MutationResolvers<ContextType = GraphqlContext, ParentType extends ResolversParentTypes['Mutation'] = ResolversParentTypes['Mutation']> = {
  createPersonalWorkspace?: Resolver<ResolversTypes['Viewer'], ParentType, ContextType, RequireFields<MutationCreatePersonalWorkspaceArgs, 'input'>>;
  updateProfile?: Resolver<ResolversTypes['Viewer'], ParentType, ContextType, RequireFields<MutationUpdateProfileArgs, 'input'>>;
};

export type ProfileResolvers<ContextType = GraphqlContext, ParentType extends ResolversParentTypes['Profile'] = ResolversParentTypes['Profile']> = {
  fullName?: Resolver<ResolversTypes['String'], ParentType, ContextType>;
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  timezone?: Resolver<ResolversTypes['String'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
};

export type QueryResolvers<ContextType = GraphqlContext, ParentType extends ResolversParentTypes['Query'] = ResolversParentTypes['Query']> = {
  viewer?: Resolver<Maybe<ResolversTypes['Viewer']>, ParentType, ContextType>;
};

export type ViewerResolvers<ContextType = GraphqlContext, ParentType extends ResolversParentTypes['Viewer'] = ResolversParentTypes['Viewer']> = {
  fullName?: Resolver<ResolversTypes['String'], ParentType, ContextType>;
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  memberships?: Resolver<Array<ResolversTypes['Membership']>, ParentType, ContextType>;
  profile?: Resolver<ResolversTypes['Profile'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
};

export type Resolvers<ContextType = GraphqlContext> = {
  Company?: CompanyResolvers<ContextType>;
  Membership?: MembershipResolvers<ContextType>;
  Mutation?: MutationResolvers<ContextType>;
  Profile?: ProfileResolvers<ContextType>;
  Query?: QueryResolvers<ContextType>;
  Viewer?: ViewerResolvers<ContextType>;
};

